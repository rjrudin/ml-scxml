xquery version "1.0-ml";

(:
Provides functions for accessing the contents of a session map. The keys are defined by the spec at 
http://www.w3.org/TR/scxml/#SystemVariables.
:)

module namespace session = "http://marklogic.com/scxml/session";

declare namespace mlsc = "http://marklogic.com/scxml";
declare namespace sc = "http://www.w3.org/2005/07/scxml";

(:
Event name is empty when a new instance is started.
:)
declare function new(
  $instance as element(mlsc:instance),
  $machine as element(sc:scxml),
  $event-name as xs:string?
  ) as map:map
{
  let $event := new-event($event-name, "external")
  
  return map:new((
    map:entry("_event", $event),
    map:entry("_sessionid", sem:uuid()),
    map:entry("_name", $machine/@name/fn:string()), 
    map:entry("_x",
      map:new((
        map:entry("instance", $instance),
        map:entry("current-states", $instance/mlsc:current-states/mlsc:current-state/fn:string()),
        map:entry("machine", $machine),
        map:entry("events", $event)
      ))
    )
  ))
};

declare private function new-event(
  $event-name as xs:string,
  $event-type as xs:string
  ) as element(event)
{
  element event {
    element name {$event-name},
    element type {$event-type}
  }
};

declare function get-instance($session as map:map) as element(mlsc:instance)
{
  map:get(get-xmap($session), "instance")
};

declare function set-instance(
  $session as map:map,
  $instance as element(mlsc:instance)
  ) as empty-sequence()
{
  map:put(get-xmap($session), "instance", $instance)
};

declare function get-machine($session as map:map) as element(sc:scxml)
{
  map:get(get-xmap($session), "machine")
};

declare function get-current-event($session as map:map) as element(event)?
{
  map:get($session, "_event")
};

declare function get-events($session as map:map) as element(event)*
{
  map:get(get-xmap($session), "events")
};

declare function get-current-states($session as map:map) as xs:string*
{
  map:get(get-xmap($session), "current-states")
};

declare function remove-current-states($session as map:map, $states-to-remove as xs:string*) as empty-sequence()
{
  map:put(
    get-xmap($session),
    "current-states",
    get-current-states($session)[fn:not(. = $states-to-remove)]
  )
};

declare function add-current-states($session as map:map, $states-to-add as xs:string*) as empty-sequence()
{
  map:put(
    get-xmap($session),
    "current-states",
    (get-current-states($session), $states-to-add)
  )
};

declare function add-event(
  $session as map:map,
  $event-name as xs:string,
  $event-type as xs:string
  ) as empty-sequence()
{
  map:put(
    get-xmap($session),
    "events",
    (get-events($session), new-event($event-name, $event-type))
  )
};

declare function remove-current-event($session as map:map) as empty-sequence()
{
  let $events := get-events($session)
  let $new-events := $events[2 to fn:last()]
  return (
    map:put($session, "_event", $new-events[1]),
    map:put(get-xmap($session), "events", $new-events)
  )
};

declare private function get-xmap($session as map:map) as map:map
{
  map:get($session, "_x")
};
