%%%-------------------------------------------------------------------
%% @doc erproxy top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(erproxy_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    SupFlags = #{
      strategy  => one_for_one,
      intensity => 0,
      period    => 1
     },
    Supervisors = [
                   erproxy_listener_sup,
                   erproxy_trans_sup
                  ],
    ChildSpecs = [
                  #{
                     id    => Module,
                     start => {Module, start_link, []},
                     type  => supervisor
                   }
                  || Module <- Supervisors
                 ],
    {ok, {SupFlags, ChildSpecs}}.

%%====================================================================
%% Internal functions
%%====================================================================
