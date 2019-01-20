/*
 * Copyright (c) 2019 Matthew Olenik <olenikm@gmail.com>
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

public class Synapse.WebPlugin: Object, Activatable, ItemProvider {

    class SearchEngine {
        public string url_template;
        public string description_template;
    }

    public bool enabled { get; set; default = true; }

    public void activate () { }

    public void deactivate () { }

    public class Result : Object, Match {
        // From Match interface
        public string title { get; construct set; }
        public string description { get; set; }
        public string icon_name { get; construct set; }
        public bool has_thumbnail { get; construct set; }
        public string thumbnail_path { get; construct set; }
        public MatchType match_type { get; construct set; }

        private AppInfo? appinfo;
        private GLib.Settings gsettings;
        private string query;
        private string search_uri;
        private string web_search_engine_id;
        private string web_search_custom_url;
        private bool web_search_enabled;

        public Result (string search) {
            gsettings = new GLib.Settings ("io.elementary.desktop.wingpanel.applications-menu");
            web_search_engine_id = gsettings.get_string ("web-search-engine-id");
            web_search_custom_url = gsettings.get_string ("web-search-custom-url");
            web_search_enabled = gsettings.get_boolean ("web-search-enabled");
            query = search;
            appinfo = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
            if (appinfo == null) {
                // No browser found
                return;
            }
            if (!web_search_enabled) {
                return;
            }
            string engine_id = web_search_engine_id;
            string url_template = get_url_template (engine_id);
            string description_template = get_description_template (engine_id);

            search_uri = url_template.replace ("{query}", Uri.escape_string (query));

            this.title = description_template.printf (query);
            this.icon_name = appinfo.get_icon ().to_string ();
            this.description = _("Search the web");
            this.has_thumbnail = false;
            this.match_type = MatchType.ACTION;
        }

        public void execute (Match? match) {
            if (!web_search_enabled) {
                return;
            }

            if (appinfo == null) {
                // No browser found
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

        private string get_url_template(string engine_id) {
            return engine_id == CUSTOM_ENGINE_ID ? web_search_custom_url : search_engines[engine_id].url_template;
        }

        private string get_description_template(string engine_id) {
            if (engine_id == null || engine_id.chomp () == "") {
                return DEFAULT_ENGINE_ID;
            }
            if (engine_id != CUSTOM_ENGINE_ID) {
                return search_engines[engine_id].description_template;
            }
            else {
                var url_template = web_search_custom_url;
                var parts = uri_regex.split(url_template);
                // For custom search, just extract the domain name of the custom URL and use that for the name.
                var domain_name = parts[2];
                var result = _("Search for %s on") + " " + domain_name;
                return result;
            }
        }
    }

    private const string DEFAULT_ENGINE_ID = "duckduckgo";
    private const string CUSTOM_ENGINE_ID = "custom";

    private static Gee.HashMap<string, SearchEngine> search_engines;

    private static Regex uri_regex;

    static void register_plugin () {
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
            url_template = _("https://www.google.com/search?q={query}"),
            description_template = _("Search the web for %s with Google")
        };
        search_engines["bing"] = new SearchEngine () {
            url_template = _("https://www.bing.com/search?q={query}"),
            description_template = _("Search the web for %s with Bing")
        };
        search_engines["duckduckgo"] = new SearchEngine () {
            url_template = _("https://duckduckgo.com/?q={query}"),
            description_template = _("Search the web for %s with DuckDuckGo")
        };
        search_engines["yahoo"] = new SearchEngine () {
            url_template = _("https://search.yahoo.com/search?p={query}"),
            description_template = _("Search the web for %s with Yahoo!")
        };
        search_engines["yandex"] = new SearchEngine () {
            url_template = _("https://yandex.com/search/?text={query}"),
            description_template = _("Search the web for %s with Yandex")
        };
        search_engines["baidu"] = new SearchEngine () {
            url_template = _("https://www.baidu.com/s?wd={query}"),
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
