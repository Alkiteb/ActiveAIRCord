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

    import flash.net.getClassByAlias;
    import flash.utils.Dictionary;

    public class Reflections
    {
        private static var _instance : Reflections;

        private static var _reflections : Dictionary;

        private static var allowInstanciation : Boolean = false;

        public function Reflections()
        {
            if (!allowInstanciation)
            {
                throw new Error("Reflections is a singleton class. Use getInstance() method.");
            }
        }

        public static function getInstance() : Reflections
        {
            if (!_instance)
            {
                allowInstanciation = true;
                _instance = new Reflections();
                allowInstanciation = false;
            }
            return _instance;
        }

        public function add( clazz : Class = null ) : Reflections
        {
            if (!_reflections[clazz])
            {
                _reflections[clazz] = new clazz();
            }
            return _instance;
        }

        public function destroy( clazz : Class ) : void
        {
            if (!_reflections[clazz])
            {
                delete _reflections[clazz];
            }
        }

        public function getClass( clazz : Class ) : Class
        {
            if (_reflections[clazz])
            {
                return _reflections[clazz];
            }
            else
            {
                throw ActiveRecordException("Class not found: " + clazz);
            }
            return null;
        }

    }
}
