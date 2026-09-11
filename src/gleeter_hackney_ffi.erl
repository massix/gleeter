-module(gleeter_hackney_ffi).

%% @doc Mirror of gleam_hackney_ffi that supports custom CA bundles set via
%% the *_SSL_CERT_FILE environment variables.
-export([send/5, load_bundle/1]).

send(Method, Url, Headers, Body, CacertFile) ->
    Options =
        case CacertFile of
            <<>> ->
                [{with_body, true}];
            File ->
                [{with_body, true},
                 {ssl_options, [{cacerts, merged_cacerts(File)}]}]
        end,
    case hackney:request(Method, Url, Headers, Body, Options) of
        {ok, Status, ResponseHeaders, ResponseBody} ->
            {ok, {response, Status, ResponseHeaders, ResponseBody}};

        {ok, Status, ResponseHeaders} ->
            {ok, {response, Status, ResponseHeaders, <<>>}};

        {error, Error} ->
            {error, {other, Error}}
    end.

%% Keep the default certifi store and append the extra CAs from the bundle so
%% that public sites keep verifying even if the bundle only has a private root.
merged_cacerts(File) ->
    certifi:cacerts() ++
        case load_bundle(File) of
            {ok, DerCerts} -> DerCerts;
            {error, _} -> []
        end.

%% Returns the DER-encoded certificates contained in a PEM bundle. On
%% unreadable or unparseable files a warning is logged and an error returned
%% (which makes the caller fall back to the default trust store).
load_bundle(File) ->
    case file:read_file(File) of
        {ok, Pem} ->
            try
                {ok, [Der || {'Certificate', Der, _} <- public_key:pem_decode(Pem)]}
            catch
                _:Reason ->
                    logger:warning("gleeter: unable to parse SSL bundle ~s: ~p",
                                   [File, Reason]),
                    {error, Reason}
            end;
        {error, Reason} ->
            logger:warning("gleeter: unable to read SSL bundle ~s: ~p",
                           [File, Reason]),
            {error, Reason}
    end.