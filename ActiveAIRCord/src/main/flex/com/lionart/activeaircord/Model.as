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

    import flash.data.SQLResult;
    import flash.utils.Dictionary;
    import flash.utils.Proxy;
    import flash.utils.describeType;
    import flash.utils.flash_proxy;
    import flash.utils.getDefinitionByName;
    import flash.utils.getQualifiedClassName;

    import org.as3commons.lang.ClassUtils;
    import org.as3commons.lang.DictionaryUtils;

    public dynamic class Model extends Proxy
    {

        public static const VALID_OPTIONS : Array = ["conditions", "limit", "offset", "order", "select", "joins", "include", "readonly", "group", "from", "having"];
        public static var aliasAttribute : Dictionary = new Dictionary(true);
        public static var _connection : SQLiteConnection;
        public static var db : String;
        public static var primaryKey : String;
        public static var sequence : String;

        private static var INHERITED_STATIC_FUNCTIONS : Array = ["tableName", "connection", "reestablishConnection", "table", "create", "deleteAll", "updateAll", "all", "count",
            "exists", "first", "last", "find", "findByPk", "findBySql", "query"];

        /* Special methods to call static methods from inheritance classes */

        public static function staticInitializer( klass : Class ) : void
        {
            var typeInfo : XML = describeType(klass);
            for each (var s : String in INHERITED_STATIC_FUNCTIONS)
            {
                klass[s] = getMethod(typeInfo.@name, s);
            }
        }

        public static function getMethod( objectName : String, methodName : String ) : Function
        {
            return function( ... args ) : Object {
                return Model[methodName](objectName, methodName, args);
            };
        }

        public static function table( objectName : String, methodName : String, ... args ) : Table
        {
            return null;
        }

        public static function all( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function count( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function create( objectName : String, methodName : String, ... args ) : void
        {
            var attributes : Array = args[0];
            var validate : Boolean = args[1] ? args[1] : true;
        }

        public static function exists( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function extractAndValidateOptions( array : Array ) : void
        {

        }

        public static function find( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function findByPk( objectName : String, methodName : String, ... args ) : void
        {
            var values : Array = args[0];
            var options : Array = args[1];
        }

        public static function findBySql( objectName : String, methodName : String, ... args ) : void
        {
            var sql : String = args[0];
            var values : Array = args[1] ? args[1] : null;
        }

        public static function first( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function connection( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function tableName( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function isOptionsHash( array : Array, throws : Boolean = true ) : void
        {

        }

        public static function last( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function pkConditions( args : Array ) : void
        {

        }

        public static function query( objectName : String, methodName : String, ... args ) : void
        {
            var sql : String = args[0];
            var values : Array = args[1] ? args[1] : null;
        }

        public static function reestablishConnection( objectName : String, methodName : String, ... args ) : void
        {

        }

        public static function transaction( closure : Function ) : void
        {

        }

        public static function updateAll( objectName : String, methodName : String, ... args ) : int
        {
            var options : Dictionary = args ? args[0] : null;
            var table : Table = Table.forClass(getDefinitionByName(objectName) as Class);
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


        public function Model( attributes : Object = null, guardAttributes : Boolean = true, instantiatingViaFind : Boolean = false, newRecord : Boolean = true )
        {
            super();
            _newRecord = newRecord;
            if (!instantiatingViaFind)
            {
                for each (var column : Column in Table.forClass(this).columns)
                {
                    // FIXME
                    //attributes[column.inflectedName] = column.defaultValue;
                }
            }

            setAttributesViaMassAssignment(attributes, guardAttributes);

            if (instantiatingViaFind)
            {
                _dirty = new Dictionary();
            }

            invokeCallback("after_consruct", false);
        }

        private var _attributes : Dictionary = new Dictionary(true);
        private var _dirty : Dictionary;
        private var _errors : Array;

        private var _item : Array;
        private var _newRecord : Boolean = true;
        private var _readOnly : Boolean = false;
        private var _relationShips : Dictionary = new Dictionary(true);

        public function assignAttribute( name : String, value : * ) : *
        {
            var table : Table = Table.forClass(this);
            if (!(value is Object))
            {
                if (DictionaryUtils.containsKey(table.columns, name))
                {
                    value = Column(table.columns[name]).cast(value, this["connection"]);
                }
                else
                {
                    var col : Column = table.getColumnByInflectedName(name);
                    if (col != null)
                    {
                        value = col.cast(value, this["connection"]);
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

        public static function deleteAll( objectName : String, methodName : String, ... args ) : int
        {
            var options : Dictionary = args ? args[0] : null;
            var table : Table = Table.forClass(getDefinitionByName(objectName) as Class);
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
                throw new ActiveRecordException("Cannot delete, no primary key defined for: " + ClassUtils.getName(ClassUtils.forInstance(this)));
            }

            if (invokeCallback("before_destroy", false))
            {
                return false;
            }

            Table.forClass(this).destroy(pk);
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
            var pk : Array = Table.forClass(this).pk;
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

        public function getValuesFor( attributes : Array ) : void
        {

        }

        public function isDirty() : Boolean
        {
            return _dirty.length > 0;
        }

        public function isInvalid() : void
        {

        }

        public function isNewRecord() : Boolean
        {
            return _newRecord;
        }

        public function isReadonly() : Boolean
        {
            return _readOnly;
        }

        public function isValid() : void
        {

        }

        public function readAttribute( name : String ) : void
        {
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

        public function updateAttributes( attributes : Array ) : void
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
            return valuesFor(Table.forClass(this).pk);
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
            if (hasOwnProperty(name))
            {
                return _item[name];
            }
            return readAttribute(name);
        }

        flash_proxy override function hasProperty( name : * ) : Boolean
        {
            return DictionaryUtils.containsKey(_attributes, name) || DictionaryUtils.containsKey(aliasAttribute, name);
        }

        flash_proxy override function setProperty( name : *, value : * ) : void
        {
            _item[name] = value;
        }

        private function insert( validation : Boolean = true ) : Boolean
        {
            verifyNotReadonly("insert");
            if (validation && !validate() || invokeCallback("before_create", false))
            {
                return false;
            }
            var table : Table = Table.forClass(this);
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
            var table : Table = Table.forClass(this);
            var exceptions : Array = [];
            var useAttrAccessible : Boolean = this["attr_accessible"];
            var useAttrProtected : Boolean = this["attr_protected"];
            var conn : SQLiteConnection = this["connection"];
            for each (var attribute : String in attributes)
            {
                var value : String;
                var name : String;
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
                        this["name"] = value;
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
                Table.forClass(this).update(dirty, pk);
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
                throw new ReadOnlyException(ClassUtils.getName(ClassUtils.forInstance(this)) + "\n" + methodName);
            }
        }
    }
}
