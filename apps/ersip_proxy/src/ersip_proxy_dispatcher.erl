%%
%% Copyright (c) 2018 Dmitry Poroh
%% All rights reserved.
%% Distributed under the terms of the MIT License. See the LICENSE file.
%%
%% Stateless proxy worker supervisor
%%

-module(ersip_proxy_dispatcher).

-export([new_request/1,
         new_response/2]).

%%====================================================================
%% API functions
%%====================================================================

new_request(Message) ->
    process_request(Message).


new_response(RecvVia, Message) ->
    process_response(RecvVia, Message).


%%====================================================================
%% Implementation
%%====================================================================

process_request(Message) ->
    case processing_type(Message) of
        {stateless, ProxyOptions} ->
            stateless_request(Message, ProxyOptions)
    end.

process_response(RecvVia, Message) ->
    stateless_response(RecvVia, Message).

processing_type(_Message) ->
    RR = ersip_uri:make(<<"sip:192.168.100.11:5090">>),
    {stateless,
     #{to_tag => ersip_id:token(crypto:strong_rand_bytes(7)),
       record_route_uri => RR,
       check_rroute_fun => fun(X) -> ersip_uri:make_key(X) == ersip_uri:make_key(RR) end
      }}.

stateless_request(Message, ProxyOptions) ->
    case ersip_proxy_common:request_validation(Message, ProxyOptions) of
        {ok, SipMsg} ->
            SipMsg1 = ersip_proxy_common:process_route_info(SipMsg, ProxyOptions),
            Target = stateless_target(SipMsg1),
            lager:info("Forward message to target: ~s", [ersip_uri:assemble(Target)]),
            {SipMsg2, #{nexthop := NexthopURI}} = ersip_proxy_common:forward_request(Target, SipMsg1, ProxyOptions),
            lager:info("Nexthop is: ~s", [ersip_uri:assemble(NexthopURI)]),
            ersip_proxy_conn:send_request(NexthopURI, SipMsg2);
        {reply, SipMsg2} ->
            lager:info("Message reply ~p", [SipMsg2]),
            TargetVia = ersip_sipmsg:get(topmost_via, SipMsg2),
            spawn_link(fun() ->
                               ersip_proxy_conn:send_response(TargetVia, undefined, SipMsg2)
                       end);
        {error, Reason} ->
            lager:warning("Error occured during processing: ~p", [Reason])
    end.

stateless_response(RecvVia, Message) ->
    case ersip_proxy_stateless:process_response(RecvVia, Message) of
        {forward, TargetVia, SipMsg} ->
            lager:info("Forward response to ~p", [TargetVia]),
            ersip_proxy_conn:send_response(TargetVia, RecvVia, SipMsg);
        {drop, Reason} ->
            lager:warning("Cannot forward message: ~p", [Reason])
    end.

stateless_target(SipMsg) ->
    ersip_sipmsg:ruri(SipMsg).
