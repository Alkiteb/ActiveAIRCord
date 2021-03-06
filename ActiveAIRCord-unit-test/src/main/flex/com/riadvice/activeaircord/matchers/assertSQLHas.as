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
package com.riadvice.activeaircord.matchers
{
    import org.as3commons.lang.StringUtils;
    import org.flexunit.asserts.assertTrue;

    public function assertSQLHas( value : String, compared : String ) : void
    {
        value = value.replace(/(\")|(`)/g, '');
        compared = compared.replace(/(\")|(`)/g, '');

        var comparisonSuccess : Boolean = StringUtils.contains(value, compared) || StringUtils.equals(value, compared);
        if (!comparisonSuccess)
        {
            trace("expected   SQL => " + value);
            trace("got result SQL => " + compared);
        }
        assertTrue(comparisonSuccess);
    }
}
