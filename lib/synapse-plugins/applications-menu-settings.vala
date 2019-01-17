// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
//
//  Copyright (C) 2011-2012 Giulio Collura
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

public class ApplicationsMenuSettings : Granite.Services.Settings {
    public int columns { get; set; }
    public int rows { get; set; }
    public bool use_category { get; set; }
    public string screen_resolution { get; set; }
    public string[] search_engine_metadata { get; set; }

    public ApplicationsMenuSettings () {
        base ("io.elementary.desktop.wingpanel.applications-menu");
    }

    protected override void verify (string key) {
        switch (key) {
            case "search-engine-metadata":
                if (search_engine_metadata.length < 3) {
                    search_engine_metadata = new string[] {
                        "duckduckgo",
                        "https://duckduckgo.com/?q={query}",
                        "Search for %s with DuckDuckGo"};
                }
                break;
        }
    }
}
