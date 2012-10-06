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
package com.lionart.activeaircord.models
{
    import com.lionart.activeaircord.Model;

    import flash.utils.Dictionary;

    public class Author extends Model
    {
        public static var pk : String = "author_id";

        public static var hasMany : Array = ["books"];

        public static var hasOne : Array = [];

        public static var belongsTo : Array = [];

        private var _password : String

        public function set password( value : String ) : void
        {
            _password = value;
        }

        public function set name( value : String ) : void
        {
            value = value.toUpperCase();
            assignAttribute("name", value);
        }

        public function returnSomething() : Dictionary
        {
            return new Dictionary({"sharks": "lasers"});
        }

    }
}
