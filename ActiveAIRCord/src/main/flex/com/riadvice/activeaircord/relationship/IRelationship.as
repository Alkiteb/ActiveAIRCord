/*
   Copyright (C) 2012-2017 RIADVICE <ghazi.triki@riadvice.tn>

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
package com.riadvice.activeaircord.relationship
{
    import com.riadvice.activeaircord.Model;
    import com.riadvice.activeaircord.Table;

    public interface IRelationship
    {
        function buildAssociation( model : Model, attributes : Array = null, guardAttributes : Boolean = true ) : *
        function createAssociation( model : Model, attributes : Array = null, guardAttributes : Boolean = true ) : Model;
        function constructInnerJoinSql( table : Table, usingThrough : Boolean = false, alias : String = null ) : String;
        function load( model : Model ) : void;
        function get attributeName() : String;
        function get isPoly() : Boolean;
        function get className() : String;
    }
}
