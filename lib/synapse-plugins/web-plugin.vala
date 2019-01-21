/*
 * Copyright (c) 2019 elementary LLC.
 *               2019 Matthew Olenik <olenikm@gmail.com>
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

    public class Result : Object, Match {
        // From Match interface
        public string title { get; construct set; }
        public string description { get; set; }
        public string icon_name { get; construct set; }
        public bool has_thumbnail { get; construct set; }
        public string thumbnail_path { get; construct set; }
        public MatchType match_type { get; construct set; }

        AppInfo? browser;
        string search_url;  // Final URL to be launched in the browser

        /* Fields corresponding to those in the gsettings schema */
        string web_search_engine_id;
        string web_search_custom_url;
        bool web_search_enabled;

        public Result (string search) {
            browser = AppInfo.get_default_for_type ("x-scheme-handler/https", false);
            if (browser == null) {
                // No browser found
                return;
            }
            web_search_enabled = gsettings.get_boolean ("web-search-enabled");
            if (!web_search_enabled) {
                return;
            }
            web_search_engine_id = gsettings.get_string ("web-search-engine-id");
            web_search_custom_url = gsettings.get_string ("web-search-custom-url");
            string url_template = get_url_template (web_search_engine_id);
            string description_template = get_description_template (web_search_engine_id);

            search_url = url_template.replace ("{query}", Uri.escape_string (search));

            this.title = description_template.printf (search);
            this.icon_name = browser.get_icon ().to_string ();
            this.description = _("Search the web");
            this.has_thumbnail = false;
            this.match_type = MatchType.ACTION;
        }

        public void execute (Match? match) {
            if (browser == null) {
                // No browser found
                return;
            }
            if (!web_search_enabled) {
                return;
            }

            var list = new List<string> ();
            list.append (search_url);

            try {
                browser.launch_uris (list, null);
            } catch (Error e) {
                error (e.message);
            }
        }

        /* Given an engine_id, find the correct URL template for that search engine.
         * e.g. "https://example.com/{query}"
         */
        string get_url_template (string engine_id) {
            if (engine_id == CUSTOM_ENGINE_ID) {
                return web_search_custom_url;
            }
            /* Fall back to the default in the rare event that the ID is unrecognized. */
            if (!search_engines.has_key (engine_id)) {
                engine_id = DEFAULT_ENGINE_ID;
            }
            return search_engines[engine_id].url_template;
        }

        /* Given an engine_id, find the correct description phrasing template.
         * This is the string in that UI that looks like "Search for %s on foo"
         */
        string get_description_template (string engine_id) {
            /* For custom search, rather than having the user bother to enter an ID/name for the search engine,
               simply use the domain name of the provider.
             */
            if (engine_id == CUSTOM_ENGINE_ID) {
                var url_template = web_search_custom_url;
                var fqdn = get_name_from_url (url_template);
                var result = _("Search for %s on") + " " + fqdn;
                return result;
            }
            /* Protect against invalid gsettings -- should not happen unless gsettings are tampered with. */
            if (engine_id == null || engine_id.chomp () == "" || !search_engines.has_key (engine_id)) {
                engine_id = DEFAULT_ENGINE_ID;
            }
            return search_engines[engine_id].description_template;
        }
    }

    public bool enabled { get; set; default = true; }
    public void activate () { }
    public void deactivate () { }

    const string DEFAULT_ENGINE_ID = "duckduckgo";
    const string CUSTOM_ENGINE_ID = "custom";
    static Gee.HashMap<string, SearchEngine> search_engines;  // Mapping of search engine metadata
    static Regex url_regex;  // Regex for extracting FQDN portion of URL
    static Settings gsettings = new GLib.Settings ("io.elementary.desktop.wingpanel.applications-menu");

    public bool handles_query (Query query) {
        return QueryFlags.TEXT in query.query_type;
    }

    public async ResultSet? search (Query query) throws SearchError {
        if (query.query_string.char_count () < 2) {
            return null;
        }
        ResultSet results = new ResultSet ();
        Result search_result = new Result (query.query_string);
        results.add (search_result, Match.Score.BELOW_AVERAGE);
        return results;
    }

    static void register_plugin () {
        DataSink.PluginRegistry.get_default ().register_plugin (
            typeof (WebPlugin),
            _("Web"),
            _("Search the web"),
            "web-browser",
            register_plugin);
    }

    /* Gets an inferred name for a search engine at a given URL */
    static string get_name_from_url (string url) {
        var parts = url_regex.split (url);
        if (parts.length > 2) {
            /* Return FQDN */
            return parts[2];
        }
        /* If no FQDN match found, just return the input.
         * This should only happen if using a custom URL that is invalid.
         */
        return url;
    }

    static construct {
        try {
            /* First capture group is protocol, second is FQDN */
            url_regex = new Regex ("""(\w+:\/\/)?([^/:\n]+)""");
        } catch (RegexError e) {
            error (e.message);
        }

        search_engines = new Gee.HashMap<string, SearchEngine?> ();
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
}
