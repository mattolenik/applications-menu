/*
* Copyright (c) 2018 Matthew Olenik <olenikm@gmail.com>
* Copyright (c) 2018 David Hewitt <davidmhewitt@gmail.com>
*               2018 elementary LLC.
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Matthew Olenik <olenikm@gmail.com>
*/

namespace Synapse {
    public class WebPlugin: Object, Activatable, ItemProvider {

        public bool enabled { get; set; default = true; }

        public void activate () { }

        public void deactivate () { }

        public class Result : Object, Match {
            // from Match interface
            public string title { get; construct set; }
            public string description { get; set; }
            public string icon_name { get; construct set; }
            public bool has_thumbnail { get; construct set; }
            public string thumbnail_path { get; construct set; }
            public MatchType match_type { get; construct set; }

            public int default_relevancy { get; set; default = 0; }

            private AppInfo? appinfo;
            private string query;
            private string bang;
            private string search_uri;

            private static Gee.HashMap<string, string> engine_names_by_bang;
            private static Gee.HashMap<string, SearchEngine?> engines_by_name;

            public Result (string search) {
                bang = get_bang(search);
                query = search.substring(bang.char_count()).strip();
                string _engine_name = get_engine_name(bang);
                SearchEngine _engine = engines_by_name[_engine_name];
                search_uri = _engine.uri_template.replace("{query}", Uri.escape_string(query));

                string _title = "";
                string _icon_name = "";

                appinfo = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
                if (appinfo != null) {
                    _title = _engine.phrase_template.printf (query);
                    _icon_name = appinfo.get_icon ().to_string ();
                }

                this.title = _title;
                this.icon_name = _icon_name;
                this.description = _("Search the web");
                this.has_thumbnail = false;
                this.match_type = MatchType.ACTION;
            }

            public void execute (Match? match) {
                if (appinfo == null) {
                    return;
                }

                var list = new List<string> ();
                list.append (search_uri);

                try {
                    appinfo.launch_uris (list, null);
                } catch (Error e) {
                    warning ("%s\n", e.message);
                }
            }

            struct SearchEngine {
                string uri_template;
                string phrase_template;
            }

            static construct {
                engine_names_by_bang = new Gee.HashMap<string, string>();
                engine_names_by_bang["!g"] = "Google";
                engine_names_by_bang["!b"] = "Bing";
                engine_names_by_bang["!d"] = "DuckDuckGo";
                engine_names_by_bang["!y"] = "Yahoo!";
                engine_names_by_bang["!w"] = "Wikipedia";

                engines_by_name = new Gee.HashMap<string, SearchEngine?>();
                engines_by_name["Google"] = SearchEngine () {
                    uri_template = _("https://www.google.com/search?q={query}"),
                    phrase_template = _("Search the web for %s with Google")
                };
                engines_by_name["Bing"] = SearchEngine () {
                    uri_template = _("https://www.bing.com/search?q={query}"),
                    phrase_template = _("Search the web for %s with Bing")
                };
                engines_by_name["DuckDuckGo"] = SearchEngine () {
                    uri_template = _("https://duckduckgo.com/?q={query}"),
                    phrase_template = _("Search the web for %s with DuckDuckGo")
                };
                engines_by_name["Yahoo!"] = SearchEngine () {
                    uri_template = _("https://search.yahoo.com/search?p={query}"),
                    phrase_template = _("Search the web for %s with Yahoo!")
                };
                engines_by_name["Wikipedia"] = SearchEngine () {
                    uri_template = _("https://wikipedia.org/wiki/Special:Search/{query}"),
                    phrase_template = _("Search Wikipedia for %s")
                };
            }

            private string get_bang(string query) {
                if (query.char_count() < 2) {
                    return "";
                }
                string result = "";
                unichar c;
                int i = 0;
                for (int count = 0; query.get_next_char (ref i, out c); count++) {
                    // Bangs start with !
                    if (count == 0 && c != '!') {
                        return "";
                    }
                    // A string staring with !! is not considered a bang
                    if (count == 1 && c == '!') {
                        return "";
                    }
                    // A space marks the end of the bang and the beginning of the query
                    if (c == ' ') {
                        return result;
                    }
                    result += c.to_string();
                }
                return result;
            }

            private string get_engine_name(string bang) {
                return engine_names_by_bang.has_key(bang) ? engine_names_by_bang[bang] : "DuckDuckGo";
            }
        }

        private static AppInfo? appinfo;

        static void register_plugin () {
            bool has_browser = false;
            appinfo = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
            // Only register the plugin if there's a web browser installed (which there almost always will be).
            if (appinfo == null) {
                has_browser = true;
            }

            DataSink.PluginRegistry.get_default ().register_plugin (typeof (WebPlugin),
                                                                    _("Web"),
                                                                    _("Search the web"),
                                                                    "web-browser",
                                                                    register_plugin);
}

        static construct {
            register_plugin ();
        }

        public bool handles_query (Query query) {
            return QueryFlags.TEXT in query.query_type;
        }

        public async ResultSet? search (Query query) throws SearchError {
            if (query.query_string.char_count() < 2) {
                return null;
            }
            ResultSet results = new ResultSet ();
            Result search_result = new Result (query.query_string);
            results.add (search_result, Match.Score.GOOD);
            return results;
        }
    }
}
