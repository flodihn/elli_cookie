%%%-------------------------------------------------------------------
%%% @author aj heller <aj@drfloob.com>
%%% @copyright (C) 2012, aj heller
%%% @doc A library module for reading and managing cookies in elli.
%%% @end
%%% Created :  3 Oct 2012 by aj heller <aj@drfloob.com>
%%%-------------------------------------------------------------------
-module(elli_cookie).

-export([parse/1, get/2, get/3, new/2, new/3, delete/1]).
-export([expires/1, path/1, domain/1, secure/0, http_only/0]).

-include_lib("elli/include/elli.hrl").

-type stringy() :: string() | binary().
-type cookie() :: {binary(), binary()}.
-type cookie_list() :: [cookie()].
-type cookie_option() :: {atom(), string()}.


%% returns a proplist made from the submitted cookies
-spec parse(Req :: #req{}) -> no_cookies | cookie_list().
parse(#req{} = Req) ->
    tokenize(elli_request:get_header(<<"Cookie">>, Req, [])).


%% gets a specific cookie value from the set of parsed cookie
-spec get(Key :: binary(), Cookies :: cookie_list()) -> undefined | binary().
get(Key, Cookies) ->
    proplists:get_value(Key, Cookies).
-spec get(Key :: binary(), Cookies :: cookie_list(), Default) -> Default | binary().
get(Key, Cookies, Default) ->
    proplists:get_value(Key, Cookies, Default).

%% creates a new cookie in a format appropriate for server response
-spec new(Name :: stringy(), Value :: stringy()) -> cookie().
new(Name, Value) ->
    BName = to_bin(Name),
    BVal = to_bin(Value),
    {<<"Set-Cookie">>, <<BName/binary, "=", BVal/binary>>}.

-spec new(Name :: stringy(), Value :: stringy(), Options :: [cookie_option()]) -> cookie().
new(Name, Value, Options) ->
    BName = to_bin(Name),
    BValue = to_bin(Value),
    Bin = <<BName/binary,"=",BValue/binary>>,
    FinalBin = lists:foldl(fun set_cookie_attribute/2, Bin, Options),
    {<<"Set-Cookie">>, FinalBin}.

%% Creates a header that will delete a specific cookie on the client
-spec delete(Name :: stringy()) -> cookie().
delete(Name) ->
    new(Name, "", [expires({{1970,1,1},{0,0,0}})]).

%%------------------------------------------------------------
%% Internal
%%------------------------------------------------------------


to_bin(B) when is_binary(B) ->
    B;
to_bin(L) when is_list(L) ->
    list_to_binary(L);
to_bin(X) ->
    throw({error, {not_a_string, X}}).



tokenize(<<>>) ->
    [];
tokenize(CookieStr) when is_binary(CookieStr) ->
    Cookies = binary:split(CookieStr, <<";">>),
    lists:map(fun tokenize2/1, Cookies);
tokenize(_) ->
    no_cookies.

tokenize2(NVP) ->
    [N,V] = binary:split(NVP, <<"=">>),
    {N, V}.
    


set_cookie_attribute({expires, Exp}, Bin) ->
    BExp = to_bin(Exp),
    <<Bin/binary, ";Expires=", BExp/binary>>;
set_cookie_attribute({path, Path}, Bin) ->
    BPath = to_bin(Path),
    <<Bin/binary, ";Path=", BPath/binary>>;
set_cookie_attribute({domain, Domain}, Bin) ->
    BDomain = to_bin(Domain),
    <<Bin/binary, ";Domain=", BDomain/binary>>;
set_cookie_attribute(secure, Bin) ->
    <<Bin/binary, ";Secure">>;
set_cookie_attribute(http_only, Bin) ->
    <<Bin/binary, ";HttpOnly">>;
set_cookie_attribute(X, _) ->
    throw({error, {invalid_cookie_attribute, X}}).



path(P) ->
    {path, P}.
domain(P) ->
    {domain, P}.
secure() ->
    secure.
http_only() ->
    http_only.



expires({S, seconds}) ->
    expires_plus(S);
expires({M, minutes}) ->
    expires_plus(M*60);
expires({H, hours}) ->
    expires_plus(H*60*60);
expires({D, days}) ->
    expires_plus(D*24*60*60);
expires({W, weeks}) ->
    expires_plus(W*7*24*60*60);
expires(Date) ->
    {expires, httpd_util:rfc1123_date(Date)}.


expires_plus(N) ->
    UT = calendar:datetime_to_gregorian_seconds(calendar:universal_time()),
    UTE = UT + N,
    Date = calendar:gregorian_seconds_to_datetime(UTE),
    {expires, httpd_util:rfc1123_date(Date)}.
    

