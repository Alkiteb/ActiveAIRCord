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

    import flash.utils.Dictionary;

    import org.as3commons.lang.StringUtils;

    public class SQLBuilder
    {
        private var _connection : SQLiteConnection;
        private var _operation : String = SQL.SELECT;
        private var _table : String;
        private var _select : String = SQL.ALL;
        private var _joins : Array;
        private var _order : String;
        private var _limit : String;
        private var _offset : String;
        private var _group : String;
        private var _having : String;
        private var _update : String;

        // For WHERE
        private var _where : String;
        private var _whereValues : Array = [];

        // For insert/update
        private var _data : *;
        private var _sequence : Array;

        public function SQLBuilder( connection : SQLiteConnection, table : String )
        {
            if (!connection)
            {
                throw new ActiveRecordException("A valid database connection is required.");
            }
            _connection = connection;
            _table = table;
        }

        public function toString() : String
        {
            // TODO
            return "";
        }

        public function get whereValues() : Array
        {
            return _whereValues;
        }

        public function bindValues() : Array
        {
            // TODO : udpate me
            return Utils.flatternArray(_data);
        }

        public function where( ... args ) : SQLBuilder
        {
            applyWhereConditions(args);
            return this;
        }

        public function order( order : String ) : SQLBuilder
        {
            _order = order;
            return this;
        }

        public function group( group : String ) : SQLBuilder
        {
            _group = group;
            return this;
        }

        public function having( having : String ) : SQLBuilder
        {
            _having = having;
            return this;
        }

        public function limit( limit : String ) : SQLBuilder
        {
            _limit = limit;
            return this;
        }

        public function offset( offset : String ) : SQLBuilder
        {
            _offset = offset;
            return this;
        }

        public function select( select : String ) : SQLBuilder
        {
            _operation = SQL.SELECT;
            _select = select;
            return this;
        }

        public function joins( joins : Array ) : SQLBuilder
        {
            _joins = joins;
            return this;
        }

        public function insert( hash : Dictionary, pk : String = null, sequenceName : String = null ) : SQLBuilder
        {
            _operation = SQL.INSERT;
            _data = hash;
            if (pk && sequenceName)
            {
                _sequence = [pk, sequenceName];
            }
            return this;
        }

        public function update( hash : * ) : SQLBuilder
        {
            _operation = SQL.UPDATE;
            if (hash is Dictionary)
            {
                _data = hash;
            }
            else if (hash is String)
            {
                _update = hash;
            }
            else
            {
                throw new ActiveRecordException("Updating requires a hash or string.");
            }

            return this;
        }

        public function destroy( ... args ) : SQLBuilder
        {
            _operation = SQL.DELETE;
            applyWhereConditions(args);
            return this;
        }

        /**
         * Reverses an order clause.
         */
        public static function reverseOrder( order : String ) : String
        {
            if (!StringUtils.trim(order))
            {
                return order;
            }

            var parts : Array = order.split(",");

            for (var i : int = 0; i < parts.length; i++)
            {
                var value : String = String(parts[i]).toLowerCase();

                if (value.search(SQL.ASC.toLowerCase()) > 0)
                {
                    parts[i] = String(parts[i]).replace(/asc/i, SQL.DESC);
                }
                else if (value.search(SQL.DESC.toLowerCase()) > 0)
                {
                    parts[i] = String(parts[i]).replace(/desc/i, SQL.ASC);
                }
                else
                {
                    parts[i] += " " + SQL.DESC;
                }
            }
            return parts.join(",");
        }

        public static function createConditionsFromUnderscoredString( connection : SQLiteConnection, name : String, values : Array, map : Dictionary = null ) : Array
        {
            if (!name)
            {
                return null;
            }

            var parts : Array = name.split(/(_and_|_or_)/i);
            var numValues : int = values.length;
            var conditions : Array = [];

            var bind : String;
            var j : int = 0;
            for (var i : int = 0; i < parts.length; i += 2)
            {
                if (i >= 2)
                {
                    conditions[0] = String(conditions[0]) + String(parts[i - 1]).replace(/_and_/i, SQL.AND).replace(/_or_/i, SQL.OR);
                }
                if (j < numValues)
                {
                    if (values[j])
                    {
                        bind = (values[j] is Array) ? (" " + SQL.IN + Expressions.PARAM) : (Expressions.EQUALS + Expressions.PARAM);
                        conditions.push(values[j]);
                    }
                    else
                    {
                        bind = [" ", SQL.IS, SQL.NULL].join(" ");
                    }
                }
                else
                {
                    bind = [" ", SQL.IS, SQL.NULL].join(" ");
                }

                // map to correct name if map was supplied
                name = map && (map[parts[i]]) ? map[parts[i]] : parts[i];

                conditions[0] = String(conditions[0]) + connection.quoteName(name) + bind;

                ++j;
            }

            return conditions;
        }

        public static function createHashFromUnderscoredString( name : String, values : Array = null, map : Dictionary = null ) : Dictionary
        {
            var parts : Array = name.split(/(_and_|_or_)/i);
            var dict : Dictionary = new Dictionary(true);

            for (var i : int = 0; i < parts.length; ++i)
            {
                name = map && map[parts[i]] ? map[parts[i]] : parts[i];
                dict[name] = values[i];
            }

            return dict;
        }

        private function prependTableNameToFields( hash : Dictionary ) : Dictionary
        {
            var result : Dictionary = new Dictionary(true);
            var table : String = _connection.quoteName(_table);

            for each (var key : String in hash)
            {
                var keyname : String = _connection.quoteName(key);
                result[[table, keyname].join(".")] = hash[key];
            }

            return result;
        }

        private function applyWhereConditions( ... args ) : void
        {
            var numArgs : int = args.length;

            if (numArgs == 1 && args[0] is Dictionary)
            {
                var dict : Dictionary = !_joins ? args[0] : prependTableNameToFields(args[0]);
                var exp : Expressions = new Expressions(_connection, dict);
                _where = exp.toString();
                _whereValues = Utils.flatternArray(exp.values);
            }
            else if (numArgs > 0)
            {
                var values : Array = args.slice(0);
            }
        }

        private function buildDestroy() : String
        {
            var sql : String = [SQL.DELETE, SQL.FROM, _table].join(" ");
            if (_where)
            {
                sql = [sql, SQL.WHERE, _where].join(" ");
            }

            if (_connection.acceptsLimitAndOrderForUpdateAndDelete())
            {
                if (_order)
                {
                    sql = [sql, SQL.ORDER, SQL.BY, _order].join(" ");
                }

                if (_limit)
                {
                    sql = _connection.limit(sql, null, _limit);
                }
            }
            return sql;
        }

        private function buildInsert() : void
        {

        }

        private function buildSelect() : String
        {
            var sql : String = [SQL.SELECT, _select, SQL.FROM, _table].join(" ");

            if (_joins)
            {
                sql = [sql, _joins].join(" ");
            }

            if (_where)
            {
                sql = [sql, _where].join(" ");
            }

            if (_group)
            {
                sql = [sql, _group].join(" ");
            }

            if (_having)
            {
                sql = [sql, _having].join(" ");
            }

            if (_order)
            {
                sql = [sql, _order].join(" ");
            }

            if (_limit || _offset)
            {
                sql = _connection.limit(sql, _offset, _limit);
            }

            return sql;
        }

        private function buildUpdate() : void
        {

        }

        private function quotedKeyNames() : Array
        {
            var keys : Array = [];
            for each (var field : String in _data)
            {
                keys.push(_connection.quoteName(_data[field]));
            }
            return keys;
        }
    }
}
