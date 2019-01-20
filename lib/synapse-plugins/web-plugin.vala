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
    class SearchEngine {
        public string query_template;
        public string description_template;
    }

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
            private string search_uri;
            private ApplicationsMenuSettings settings;

            public Result (string search) {
                query = search;
                settings = new ApplicationsMenuSettings ();
                if (!settings.web_search_enabled) {
                    return;
                }
                var metadata = settings.web_search_engine;
                if (metadata == null || metadata.length == 0) {
                    metadata = new string[] { default_engine };
                }
                string engine_id = metadata[0];
                string query_template = "";
                string description_template = "";
                // ID only, use built-in metadata.
                if (metadata.length == 1) {
                    query_template = search_engines[engine_id].query_template;
                    description_template = search_engines[engine_id].description_template;
                }
                // ID plus metadata found, use that metadata. Used for custom search engines.
                else if (metadata.length > 1) {
                    query_template = metadata[1];
                    var parts = uri_regex.split(query_template);
                    // For custom search, just extract the domain name of the custom URL and use that for the name.
                    var domain_name = parts[2];
                    description_template = _("Search for %s on") + " " + domain_name;
                } else {
                    debug("ERROR: bad metadata");
                }

                search_uri = query_template.replace ("{query}", Uri.escape_string (query));
                string _title = description_template.printf (query);
                string _icon_name = "";

                appinfo = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
                if (appinfo != null) {
                    _icon_name = appinfo.get_icon ().to_string ();
                }

                this.title = _title;
                this.icon_name = _icon_name;
                this.description = _("Search the web");
                this.has_thumbnail = false;
                this.match_type = MatchType.ACTION;
            }

            public void execute (Match? match) {
                if (!settings.web_search_enabled) {
                    return;
                }

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
        }

        private static AppInfo? appinfo;

        private static Gee.HashMap<string, SearchEngine> search_engines;

        private const string default_engine = "duckduckgo";

        private static Regex uri_regex;

        static void register_plugin () {
            appinfo = AppInfo.get_default_for_type ("x-scheme-handler/https", false);

            DataSink.PluginRegistry.get_default ().register_plugin (
                typeof (WebPlugin),
                _("Web"),
                _("Search the web"),
                "web-browser",
                register_plugin);
        }

        static construct {
            try {
            uri_regex = new Regex ("""(\w+:\/\/)?([^/:\n]+)""");
            } catch (RegexError e) {
                debug(e.message);
            }

            search_engines = new Gee.HashMap<string, SearchEngine?>();
            search_engines["google"] = new SearchEngine () {
                query_template = _("https://www.google.com/search?q={query}"),
                description_template = _("Search the web for %s with Google")
            };
            search_engines["bing"] = new SearchEngine () {
                query_template = _("https://www.bing.com/search?q={query}"),
                description_template = _("Search the web for %s with Bing")
            };
            search_engines["duckduckgo"] = new SearchEngine () {
                query_template = _("https://duckduckgo.com/?q={query}"),
                description_template = _("Search the web for %s with DuckDuckGo")
            };
            search_engines["yahoo"] = new SearchEngine () {
                query_template = _("https://search.yahoo.com/search?p={query}"),
                description_template = _("Search the web for %s with Yahoo!")
            };
            search_engines["yandex"] = new SearchEngine () {
                query_template = _("https://yandex.com/search/?text={query}"),
                description_template = _("Search the web for %s with Yandex")
            };
            search_engines["baidu"] = new SearchEngine () {
                query_template = _("https://www.baidu.com/s?wd={query}"),
                description_template = _("Search the web for %s with Baidu")
            };
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
            results.add (search_result, Match.Score.BELOW_AVERAGE);
            return results;
        }
    }
}
