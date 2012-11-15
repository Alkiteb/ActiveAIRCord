/*
   Copyright (C) 2012 Ghazi Triki <ghazi.nocturne@gmail.com>

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program. If not, see <http://www.gnu.org/licenses/>.
 */
package com.lionart.activeaircord
{
    import com.lionart.activeaircord.exceptions.ActiveRecordException;
    import com.lionart.activeaircord.exceptions.ReadOnlyException;
    import com.lionart.activeaircord.exceptions.RecordNotFound;
    import com.lionart.activeaircord.exceptions.UndefinedPropertyException;
    
    import flash.data.SQLResult;
    import flash.utils.Dictionary;
    import flash.utils.Proxy;
    import flash.utils.describeType;
    import flash.utils.flash_proxy;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;
    
    import mx.collections.ArrayCollection;
    
    import org.as3commons.lang.ArrayUtils;
    import org.as3commons.lang.ClassUtils;
    import org.as3commons.lang.DictionaryUtils;
    import org.as3commons.lang.ObjectUtils;

    public dynamic class Model extends Proxy
    {

        public static const VALID_OPTIONS : Array = ["conditions", "limit", "offset", "order", "select", "joins", "include", "readonly", "group", "from", "having"];
        public static var aliasAttribute : Dictionary = new Dictionary(true);
        public static var _connection : SQLiteConnection;
        public static var db : String;
        public static var primaryKey : String;
        public static var sequence : String;

        private static var INHERITED_STATIC_FUNCTIONS : Array = ["getTableName", "getConnection", "reestablishConnection", "getTable", "create", "deleteAll", "updateAll", "all", "count", "exists", "first", "last", "find", "findByPk", "findBySql", "query", "isOptionsHash", "pkConditions", "extractAndValidateOptions"];

        /* Special methods to call static methods from inheritance classes */

        public static function staticInitializer( clazz : Class ) : void
        {
            var typeInfo : XML = describeType(clazz);
            for each (var s : String in INHERITED_STATIC_FUNCTIONS)
            {
                clazz[s] = getMethod(typeInfo.@name, s);
            }
        }

        public static function getMethod( objectName : String, methodName : String ) : Function
        {
            return function( ... args ) : Object {
                // FIXME : this workaround is not the final solution to pass the correct arguments
                // to the called method. Passing one or more arguments : the behavior changes, it
                // must be understood correctly to be handled correctly
                var argsToPass : *;
                if (methodName == 'find' && args.length > 1)
                {
                    argsToPass = args;
                }
                else
                {
                    argsToPass = args[0];
                }
                //var argsToPass : Array = (args.length > 1 || (args.length == 1 && (args[0] is Array))) ? args : args[0];
                return Model[methodName](getDefinitionByName(objectName), methodName, argsToPass);
            };
        }

        private var _attributes : Dictionary = new Dictionary(true);
        private var _dirty : Dictionary;
        private var _errors : Array;

        private var _item : Array;
        private var _newRecord : Boolean = true;
        private var _readOnly : Boolean = false;
        private var _relationShips : Dictionary = new Dictionary(true);

        private var _clazz : Class;

        public function Model( attributes : Object = null, guardAttributes : Boolean = true, instantiatingViaFind : Boolean = false, newRecord : Boolean = true )
        {
            super();

            _clazz = ClassUtils.forInstance(this);
            _newRecord = newRecord;
            if (!instantiatingViaFind)
            {
                for each (var column : Column in Table(ClassUtils.forInstance(this)["getTable"]()).columns)
                {
                    _attributes[column.inflectedName] = column.defaultValue;
                }
            }

            setAttributesViaMassAssignment(attributes, guardAttributes);

            if (instantiatingViaFind)
            {
                _dirty = new Dictionary();
            }

            invokeCallback("after_consruct", false);
        }

        public static function getTable( clazz : Class, methodName : String, ... args ) : Table
        {
            return Table.load(ClassUtils.getName(clazz));
        }

        public static function all( clazz : Class, methodName : String, ... args ) : ArrayCollection
        {
            return clazz["find"](ArrayUtils.addAll(args, ["all"]));
        }

        public static function count( clazz : Class, methodName : String, ... args ) : int
        {
            var options : Dictionary = clazz["extractAndValidateOptions"](args);
            options["select"] = [SQL.COUNT + "(" + SQL.ASTERISK + ")"].join();

            if (!ArrayUtils.isEmpty(args) && args[0] != null && !ArrayUtils.isEmpty(args[0]))
            {
                if (args[0] is Dictionary)
                {
                    options["conditions"] = args[0];
                }
                else
                {
                    options["condition"] = clazz["pkConditions"](args);
                }
            }

            var table : Table = clazz["getTable"]();
            var sql : SQLBuilder = table.optionsToSql(options);
            var values : Array = sql.whereValues;
            return SQLiteConnection(clazz["connection"]()).queryAndFetchOne(sql.toString(), values) as int;
        }

        public static function create( clazz : Class, methodName : String, ... args ) : void
        {
            var attributes : Array = args[0];
            var validate : Boolean = args[1] ? args[1] : true;
        }

        public static function exists( clazz : Class, methodName : String, ... args ) : Boolean
        {
            return clazz["count"]() > 0 ? true : false;
        }

        public static function extractAndValidateOptions( clazz : Class, methodName : String, ... args ) : Dictionary
        {
            var array : Array = args[0];
            var options : Dictionary = new Dictionary();

            if (array)
            {
                var last : * = array[array.length - 1];
                try
                {
                    if (clazz["isOptionsHash"](last))
                    {
                        array.pop();
                        options = last;
                    }
                }
                catch ( e : ActiveRecordException )
                {
                    if (!(last is Dictionary))
                    {
                        throw e;
                    }
                    options["conditions"] = last;
                }
            }
            return options;
        }

        public static function find( clazz : Class, methodName : String, ... args ) : *
        {
            // FIXME : this method must work whatever args are passed to it
            var params : Array = args[0];
            if (!params || params.length == 0)
            {
                throw new RecordNotFound("Couldn't find " + ClassUtils.getName(clazz) + " without an ID");
            }

            var options : Dictionary = clazz["extractAndValidateOptions"](params);
            var numArgs : int = params.length;
            var single : Boolean = true;
            // Only one argument is passed
            var oneArgs : * = null;

            if (numArgs > 0 && (params[0] == "all" || params[0] == "first" || params[0] == "last"))
            {
                switch (params[0])
                {
                    case "all":
                        single = false;
                        break;

                    case "last":
                        if (!DictionaryUtils.containsKey(options, "order"))
                        {
                            options["order"] = [SQL.DESC, Table(clazz["getTable"]()).pk, SQL.DESC].join(" ");
                        }
                        else
                        {
                            options["order"] = SQLBuilder.reverseOrder(options["order"]);
                        }
                        break;
                    case "first":
                        options["limit"] = 1;
                        options["offset"] = 0;
                        break;
                    default:
                        break;
                }
                params = params.splice(1);
                numArgs--;
            }
            else if (params.length == numArgs == 1)
            {
                oneArgs = params[0];
            }

            // anything left in $args is a find by pk
            if (numArgs > 0 && !options["conditions"])
            {
                return clazz["findByPk"](oneArgs ? oneArgs : params, options);
            }

            options["mappedNames"] = clazz["aliasAttribute"] || new Array();
            var list : Array = Table(clazz["getTable"]()).find(options);

            return single ? (list.length > 0 ? list[0] : null) : list;
        }

        public static function findByPk( clazz : Class, methodName : String, ... args ) : Array
        {
            var values : * = args[0];
            // FIXME : options is not passed via getMethod the second time
            var options : Dictionary = args[1] || new Dictionary(true);
            options["conditions"] = clazz["pkConditions"](values);
            var list : Array = Table(clazz["getTable"]()).find(options);
            var results : int = list.length;
            // FIXME
            var expected : int = (values is Array) ? values.length : 1

            if (results != expected)
            {
                if (expected == 1)
                {
                    var expectedValues : Array;
                    if (!(values is Array))
                    {
                        expectedValues = new Array(values);
                    }
                    else
                    {
                        expectedValues = values;
                    }
                    throw new RecordNotFound("Couldn't find " + ClassUtils.getName(clazz) + " with ID=" + expectedValues.join(","));
                }
                throw new RecordNotFound("Couldn't find all " + ClassUtils.getName(clazz) + " with IDs (" + values.join(",") + ") (found " + results + ", but was looking for " + expected + ")");
            }

            return expected == 1 ? list[0] : list;
        }

        public static function findBySql( clazz : Class, methodName : String, ... args ) : Array
        {
            var sql : String = args[0];
            var values : Array = args[1] ? args[1] : null;
            return Table(clazz["getTable"]()).findBySql(sql, values, true);
        }

        public static function first( clazz : Class, methodName : String, ... args ) : ArrayCollection
        {
            return clazz["find"](ArrayUtils.addAll(args, ["first"]));
        }

        public static function getConnection( clazz : Class, methodName : String, ... args ) : SQLiteConnection
        {
            return Table(clazz["getTable"]()).conn;
        }

        public static function getTableName( clazz : Class, methodName : String, ... args ) : String
        {
            return Table(clazz["getTable"]()).tableName;
        }

        public static function isOptionsHash( clazz : Class, methodName : String, ... args ) : Boolean
        {
            var array : * = args[0];
            var throws : Boolean = args.length == 2 ? args[1] : true;
            if (array && ClassUtils.forInstance(array) == Object)
            {
                array = ObjectUtils.toDictionary(array);
            }
            if (array is Dictionary)
            {
                var keys : Array = DictionaryUtils.getKeys(array);
                var diff : Array = Utils.arrayDiff(keys, VALID_OPTIONS);

                if (!ArrayUtils.isEmpty(diff) && throws)
                {
                    throw new ActiveRecordException("Unknown key(s): " + diff.join(","));
                }

                var intersect : Array = Utils.arrayIntersect(keys, VALID_OPTIONS);

                if (!ArrayUtils.isEmpty(intersect))
                {
                    return true;
                }
            }
            return false;
        }

        public static function last( clazz : Class, methodName : String, ... args ) : ArrayCollection
        {
            return clazz["find"](ArrayUtils.addAll(args, ["last"]));
        }

        public static function pkConditions( clazz : Class, methodName : String, ... args ) : Dictionary
        {
            var table : Table = clazz["getTable"]();
            var result : Dictionary = new Dictionary();
            result[table.pk[0]] = args[0];
            return result;
        }

        public static function query( clazz : Class, methodName : String, ... args ) : void
        {
            var sql : String = args[0];
            var values : Array = args[1] ? args[1] : null;
        }

        public static function connection( clazz : Class, methodName : String, ... args ) : SQLiteConnection
        {
            return Table(clazz["getTable"]()).conn;
        }

        public static function reestablishConnection( clazz : Class, methodName : String, ... args ) : void
        {

        }

        public static function transaction( closure : Function ) : void
        {

        }

        public static function updateAll( clazz : Class, methodName : String, ... args ) : int
        {
            var options : Dictionary = args ? args[0] : null;
            var table : Table = clazz["getTable"]();
            var conn : SQLiteConnection = _connection;
            var sql : SQLBuilder = new SQLBuilder(conn, table.getFullyQualifiedTableName());

            sql.update(options["set"]);

            // TODO : call custom user function
            var conditions : Array = options["conditions"];
            sql.where(conditions);


            if (options["limit"])
            {
                sql.limit(options["limit"]);
            }

            if (options["order"])
            {
                sql.limit(options["order"]);
            }

            var values : Array = sql.bindValues();
            var result : SQLResult = conn.query((table.lastSql = sql.toString()), values);
            return result.rowsAffected;
        }

        private static function internalTable() : void
        {

        }

        public function assignAttribute( name : String, value : * ) : *
        {
            var table : Table = ClassUtils.forInstance(this)["getTable"]();
            if (!(value is Object))
            {
                if (DictionaryUtils.containsKey(table.columns, name))
                {
                    value = Column(table.columns[name]).cast(value, _clazz["getConnection"]());
                }
                else
                {
                    var col : Column = table.getColumnByInflectedName(name);
                    if (col != null)
                    {
                        value = col.cast(value, _clazz["getConnection"]());
                    }
                }
            }

            attributes()[name] = value;
            flagDirty(name);
            return value;
        }

        public function attributeIsDirty( attribute : String ) : Boolean
        {
            return _dirty && _dirty[attribute] && DictionaryUtils.containsKey(attributes(), attribute);
        }

        public function attributes() : Dictionary
        {
            return _attributes;
        }

        public function clone() : void
        {

        }

        public static function deleteAll( clazz : Class, methodName : String, ... args ) : int
        {
            var options : Dictionary = args ? args[0] : null;
            var table : Table = clazz["getTable"]();
            var conn : SQLiteConnection = _connection;
            var sql : SQLBuilder = new SQLBuilder(conn, table.getFullyQualifiedTableName());

            // FIXME : pass object instead of Dictionary
            var conditions : Dictionary = options["conditions"];

            // TODO : call custom user function
            sql.destroy(conditions);

            if (options["limit"])
            {
                sql.limit(options["limit"]);
            }

            if (options["order"])
            {
                sql.limit(options["order"]);
            }

            var values : Array = sql.bindValues();
            var result : SQLResult = conn.query((table.lastSql = sql.toString()), values);
            return result.rowsAffected;
        }

        public function destroy() : Boolean
        {
            verifyNotReadonly("destroy");

            var pk : Dictionary = valuesForPk();

            // FIXME : calculate dictionary length using a different way
            if (DictionaryUtils.getKeys(pk).length == 0)
            {
                throw new ActiveRecordException("Cannot delete, no primary key defined for: " + _clazz);
            }

            if (invokeCallback("before_destroy", false))
            {
                return false;
            }

            prototype.constructor["getTable"]().destroy(pk);
            invokeCallback("after_destroy", false)

            return true;
        }

        public function dirtyAttributes() : Dictionary
        {
            if (!_dirty)
            {
                return null;
            }
            // TODO
            return null;
        }

        public function get errors() : Array
        {
            return _errors;
        }

        public function set errors( value : Array ) : void
        {
            _errors = value;
        }

        public function flagDirty( name : String ) : void
        {
            if (!_dirty)
            {
                _dirty = new Dictionary();
            }
            _dirty[name] = true;
        }

        public function getPrimaryKey( first : Boolean = false ) : *
        {
            var pk : Array = prototype.constructor["getTable"]().pk;
            return first ? pk[0] : pk;
        }

        public function getRealAttributeName( name : String ) : String
        {
            if (DictionaryUtils.containsKey(attributes(), name))
            {
                return name;
            }
            if (DictionaryUtils.containsKey(this["alias_attribute"], name))
            {
                return this["alias_attribute"][name];
            }
            return null;
        }

        public function getValidationRules() : Dictionary
        {
            var validator : Validations = new Validations(this);
            return validator.rules();
        }

        public function getValuesFor( attributes : Dictionary ) : Dictionary
        {
            var result : Dictionary = new Dictionary(true);

            for (var key : String in attributes)
            {
                if (DictionaryUtils.containsKey(_attributes, key))
                {
                    result[key] = _attributes[key]
                }
            }

            return result;
        }

        public function isDirty() : Boolean
        {
            return _dirty.length > 0;
        }

        public function isInvalid() : Boolean
        {
            return !validate();
        }

        public function isNewRecord() : Boolean
        {
            return _newRecord;
        }

        public function isReadonly() : Boolean
        {
            return _readOnly;
        }

        public function isValid() : Boolean
        {
            return validate();
        }

        public function readAttribute( name : String ) : *
        {
            if (hasOwnProperty(name))
            {
                return _item[name];
            }
            if (DictionaryUtils.containsKey(attributes(), name))
            {
                return attributes()[name];
            }

            // TODO : complete
            throw new UndefinedPropertyException(ClassUtils.getName(_clazz), name);
        }

        public function readonly( readonly : Boolean = true ) : void
        {

        }

        public function reload() : void
        {

        }

        public function resetDirty() : void
        {

        }

        public function save( validate : Boolean = true ) : Boolean
        {
            verifyNotReadonly("save");
            return isNewRecord() ? insert(validate) : update(validate);
        }

        public function setAttributes( attributes : Dictionary ) : void
        {

        }

        public function setRelationshipFromEagerLoad( name : String, model : Model = null ) : void
        {

        }

        public function setTimestamps() : void
        {
            var now : Date = new Date();

            if (this["updatedAt"])
            {
                this["updatedAt"] = now;
            }
            if (this["createdAt"] && isNewRecord())
            {
                this["createdAt"] = now;
            }
        }

        public function toArray( options : Array = null ) : void
        {

        }

        public function toCsv( options : Array = null ) : void
        {

        }

        public function toJson( options : Array = null ) : void
        {

        }

        public function toXml( options : Array = null ) : void
        {

        }

        public function updateAttribute( name : String, value : * ) : void
        {

        }

        public function updateAttributes( attributes : Dictionary ) : void
        {

        }

        public function valuesFor( attributeNames : Array ) : Dictionary
        {
            var filter : Dictionary = new Dictionary();

            for each (var name : String in attributeNames)
            {
                filter[name] = this[name];
            }

            return filter;
        }

        public function valuesForPk() : Dictionary
        {
            return valuesFor(prototype.constructor["getTable"]().pk);
        }

        flash_proxy override function callProperty( methodName : *, ... parameters ) : *
        {
            try
            {
                var clazz : Class = getDefinitionByName(getQualifiedClassName(this)) as Class;
                return clazz.prototype[methodName].apply(methodName, parameters);
            }
            catch ( e : Error )
            {
                return methodMissing(methodName, parameters);
            }
        /*var res : *;
           switch (methodName.toString())
           {
           /*case "clear":
           _item = new Array();
           break;
           case "sum":
           var sum:Number = 0;
           for each (var i:* in _item) {
           // ignore non-numeric values
           if (!isNaN(i)) {
           sum += i;
           }
           }
           res = sum;
           break;*/
        /*default:
           res = _item[methodName].apply(_item, parameters);
           break;
           }
           return res;*/
        }

        protected function methodMissing( method : *, args : Array ) : Object
        {
            throw(new Error("Method Missing"));
            return null;
        }

        flash_proxy override function getProperty( name : * ) : *
        {
            // TODO : must look in attributes dictionary
            var propName : String = (name is QName) ? QName(name).localName : name;
            if (hasOwnProperty(propName))
            {
                return _item[propName];
            }
            return readAttribute(propName);
        }

        flash_proxy override function hasProperty( name : * ) : Boolean
        {
            return DictionaryUtils.containsKey(_attributes, name) || DictionaryUtils.containsKey(aliasAttribute, name);
        }

        flash_proxy override function setProperty( name : *, value : * ) : void
        {
            var propName : String = (name is QName) ? QName(name).localName : name;
            if (hasOwnProperty(propName))
            {
                _item[name] = value;
            }
            if (DictionaryUtils.containsKey(attributes(), name))
            {
                assignAttribute(propName, value);
            }

            // TODO : complete

            throw new UndefinedPropertyException(ClassUtils.getName(_clazz), propName);
        }

        private function insert( validation : Boolean = true ) : Boolean
        {
            verifyNotReadonly("insert");
            if (validation && !validate() || invokeCallback("before_create", false))
            {
                return false;
            }
            var table : Table = prototype.constructor["getTable"]();
            var attributes : Dictionary;
            if (!(attributes = dirtyAttributes()))
            {
                attributes = _attributes;
            }
            var pk : Array = getPrimaryKey(true);
            table.insert(attributes);

            invokeCallback("after_create", false);
            _newRecord = false;

            return true;
        }

        private function invokeCallback( methodName : String, mustExist : Boolean = true ) : void
        {

        }

        private function isDelegated( name : String, delegate : Array ) : void
        {

        }

        private function serialize( type : String, options : Array ) : void
        {

        }

        private function setAttributesViaMassAssignment( attributes : Object, guardAttributes : Boolean ) : void
        {
            var table : Table = _clazz["getTable"]();
            var exceptions : Array = [];
            var useAttrAccessible : Boolean = false; // FIXME : this["attr_accessible"];
            var useAttrProtected : Boolean = false; // FIXME : this["attr_protected"];
            var conn : SQLiteConnection = _clazz["getConnection"]();
            for (var attribute : String in attributes)
            {
                var name : String = attribute;
                var value : * = attributes[attribute];
                if (DictionaryUtils.containsKey(table.columns, attributes))
                {
                    value = Column(table.columns[attribute]).cast(attributes[attribute], conn);
                    name = Column(table.columns[attribute]).inflectedName;
                }
                if (guardAttributes)
                {
                    if (useAttrAccessible && !DictionaryUtils.containsKey(this["attr_accessible"], name))
                    {
                        continue;
                    }
                    if (useAttrProtected && !DictionaryUtils.containsKey(this["attr_protected"], name))
                    {
                        continue;
                    }
                    try
                    {
                        this[name] = value;
                    }
                    catch ( e : Error )
                    {
                        exceptions.push(e.message);
                    }
                }
                else
                {
                    assignAttribute(name, value);
                }
            }
            if (!ArrayUtils.isEmpty(exceptions))
            {
                throw new UndefinedPropertyException(ClassUtils.getName(ClassUtils.forInstance(this)), exceptions)
            }
        }

        private function update( validation : Boolean = true ) : Boolean
        {
            verifyNotReadonly("update");

            if (validation && !validate())
            {
                return false;
            }

            if (isDirty())
            {
                var pk : Dictionary = valuesForPk();
                if (!pk)
                {
                    throw new ActiveRecordException("Cannot update, no primary key defined for: " + ClassUtils.forInstance(this).toString());
                }
                if (!invokeCallback("before_update", false))
                {
                    return false;
                }
                var dirty : Dictionary = dirtyAttributes();
                ClassUtils.forInstance(this)["getTable"]().update(dirty, pk);
                invokeCallback("after_update", false);
            }
            return true;
        }

        private function validate() : Boolean
        {
            return true;
        }

        private function verifyNotReadonly( methodName : String ) : void
        {
            if (isReadonly())
            {
                throw new ReadOnlyException(_clazz + "\n" + methodName);
            }
        }
    }
}
