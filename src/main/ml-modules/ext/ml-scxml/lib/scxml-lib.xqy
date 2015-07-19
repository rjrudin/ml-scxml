xquery version "1.0-ml";

(:
This library is intended to not perform any persistence operations; it just implements SCXML functionality.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlscxp = "http://marklogic.com/scxml/extension-points" at 
  "/ext/ml-scxml/extension-points/build-transition.xqy",
  "/ext/ml-scxml/extension-points/on-event.xqy";
import module namespace session = "http://marklogic.com/scxml/session" at "/ext/ml-scxml/lib/session-lib.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare variable $TRACE-EVENT := "ml-scxml";

declare function start(
  $machine-id as xs:string,
  $machine as element(sc:scxml),
  $instance-id as xs:string
  ) as element(mlsc:instance)
{
  let $initial-state := ($machine/sc:initial, $machine/(sc:state|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]
  let $_ := xdmp:trace($TRACE-EVENT, "Starting machine with id " || $machine-id || " and initial state " || $initial-state/@id)
  
  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:active-states {
      element mlsc:active-state {$initial-state/@id/fn:string()}
    },
    
    let $data := $machine//sc:datamodel/sc:data
    where $data
    return element sc:datamodel { $data }
  }
  
  return enter-states($initial-state, (), session:new($instance, $machine, ()))
};


(:
Starts a new session and processes the given event. 
:)
declare function handle-event(
  $instance as element(mlsc:instance),
  $machine as element(sc:scxml),
  $event-name as xs:string
  ) as element(mlsc:instance)
{
  let $session := session:new($instance, $machine, $event-name)
  
  return (
    handle-next-event($session),
    session:get-instance($session)
  )
};


(:
Gets the current event, and if one exists, processes it (which means find all the states that have transitions with
that event, and execute each matching transition, updating the instance document as we go), then remove the current
event, then call handle-next-event in case one or more events were added.
:)
declare function handle-next-event($session as map:map) as empty-sequence()
{
  let $event := session:get-current-event($session)
  where $event
  return 
  
    let $event-name := $event/name/fn:string()
    let $instance := session:get-instance($session)
    let $machine := session:get-machine($session)
    
    let $_ := xdmp:trace($TRACE-EVENT, ("Handling event " || $event-name || " for instance " || get-instance-id($instance)))
  
    let $current-states := $machine//(sc:state|sc:initial|sc:parallel)[@id = get-active-states($instance)]
    
    return (
      for $current-state in $current-states 
      let $transition := (
        $current-state/sc:transition[@event = $event-name],
        $current-state/sc:transition[@event = "*"]
      )[1]
      
      return
        if ($transition) then
          session:set-instance($session, execute-transition($transition, $current-state, $session))
        else
          xdmp:trace($TRACE-EVENT, ("Discarding event '" || $event-name || "'; could not find transition for it")),
      
      session:remove-current-event($session),
      
      handle-next-event($session)
    )
};


(:
This implementation assumes that initial/state/final IDs are unique. I can't think of a good reason for them not to be,
and things would get very confusing if they weren't.
:)
declare function execute-transition(
  $transition as element(sc:transition),
  $current-state as element(),
  $session as map:map
  ) as element(mlsc:instance)
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  
  let $_ := xdmp:trace($TRACE-EVENT, ("Executing transition for instance " || get-instance-id($instance), $transition))
  
  let $target := fn:string($transition/@target)
  let $new-state := $machine//(sc:state|sc:final)[@id = $target]
  
  return
    if ($new-state) then
      let $parallel := $new-state/ancestor::sc:parallel
      return
        if ($parallel) then
        
          (:
          If we're entering this parallel and the instance doesn't have any active states that match those of the child
          states of the parallel element, we need to initialize an active state for each child state of the parallel element.
          And we add the id of the parallel as an active state as well.
          :)
          let $active-states := get-active-states($instance)
          let $entering-parallel := fn:not($active-states = $parallel//(sc:initial|sc:state|sc:final)/@id/fn:string())
          let $_ := xdmp:trace($TRACE-EVENT, "Entering parallel? " || $entering-parallel)

          return
            if ($entering-parallel) then           
              let $other-states := $parallel/sc:state[fn:not(@id = $target) and fn:not(.//sc:state[@id = $target])]
              let $other-initial-states := 
                for $other-state in $other-states
                return $other-state/sc:state[@id = $other-state/@initial]
              
              return enter-states(($parallel, $new-state, $other-initial-states), $current-state, $session)
            else
              enter-states($new-state, $current-state, $session)
          
        else
          enter-states($new-state, $current-state, $session)
          
    else
      (: The spec says to just "discard" the event, but for now, throwing an error to signify an issue :)
      fn:error(xs:QName("MISSING-STATE"), "Could not find state '" || $target || "' to transition to for event '" || $transition/@event || "'")
};


declare function enter-states(
  $new-states as element()+,
  $current-state as element()?,
  $session as map:map
  ) as element(mlsc:instance)
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  
  let $_ := xdmp:trace($TRACE-EVENT, "Entering state(s) " || fn:string-join($new-states/@id, ",") || " for instance " || get-instance-id($instance))
  
  let $_ := 
    (: According to the example in 3.1.3 of the spec, we raise an event for the parent state when we reach the final child state :)
    for $state in $new-states[self::sc:final]
    let $parent := $state/..[self::sc:state]
    where $parent
    return 
      let $event-name := "done.state." || $parent/@id
      return (
        xdmp:trace($TRACE-EVENT, "Raising event " || $event-name || " for instance " || get-instance-id($instance)),
        session:add-event($session, $event-name, "internal"),
        mlscxp:on-event($event-name, $state, $machine, $instance),
        
        (: If this is part of a parallel, and all other parts are final, then raise an event for the parallel too :)
        let $parallel := $parent/..[self::sc:parallel]
        where $parallel
        return
          let $final-state-ids := $parallel/sc:state/sc:final/@id/fn:string
          let $active-states := $instance/mlsc:active-states/mlsc:active-state/fn:string()
          let $unfinished-state-ids := 
            for $state-id in $final-state-ids
            where fn:not($state-id = ($active-states, $parent/@id))
            return $state-id
          where fn:not($unfinished-state-ids)
          return
            let $event-name := "done.state." || $parallel/@id
            return (
              xdmp:trace($TRACE-EVENT, "Raising event " || $event-name || " for instance " || get-instance-id($instance)),
              session:add-event($session, $event-name, "internal"),
              mlscxp:on-event($event-name, $state, $machine, $instance)
            )
      )
  
  let $datamodel := $instance/sc:datamodel
  
  let $datamodel := execute-executable-content($current-state/sc:onexit/element(), $datamodel)
  let $datamodel := execute-executable-content($new-states/sc:onentry/element(), $datamodel)

  let $transitions := mlscxp:build-transition($new-states, $current-state, $machine, $instance) 
  
  let $states-to-retain := $instance/mlsc:active-states/mlsc:active-state[fn:not(. = $current-state/@id)]
  
  let $new-active-states := 
    element mlsc:active-states {
      $states-to-retain,
      for $state in $new-states
      let $id := fn:string($state/@id)
      where fn:not($id = $states-to-retain/fn:string())
      return element mlsc:active-state {$id}
    }
  
  return element {fn:node-name($instance)} {
    $instance/@*,
    
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:active-states) return $new-active-states
      case element(sc:datamodel) return $datamodel
      case element(mlsc:transitions) return 
        element mlsc:transitions {
          $kid/*,
          $transitions
        }
      default return $kid,
      
    if (fn:not($instance/mlsc:transitions)) then 
      element mlsc:transitions {$transitions}
    else ()
  }
};


declare function execute-executable-content(
  $executable-content-elements as element()*,
  $datamodel as element(sc:datamodel)
  ) as element(sc:datamodel)
{
  let $_ := 
    for $el in $executable-content-elements
    return typeswitch ($el)
      case element(sc:log) return xdmp:log(xdmp:eval($el/@expr))
      case element(sc:assign) return xdmp:set($datamodel, execute-assign($el, $datamodel))
      case element(sc:script) return xdmp:set($datamodel, execute-script($el, $datamodel))
      default return ()
  
  return $datamodel
};


(:
Using XSLT to transform the datamodel based on the location and expression in the assign block. Don't yet know a way to
do this in just XQuery.
:)
declare function execute-assign(
  $assign as element(sc:assign),
  $datamodel as element(sc:datamodel)
  ) as element(sc:datamodel)
{
  let $location := $assign/@location/fn:string()
  let $data-id := fn:substring(fn:tokenize($location, "/")[1], 2)
  let $data-path := "/" || fn:substring-after($location, "/")
  
  let $expr := $assign/@expr/fn:string()
  
  let $stylesheet := 
    <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:sc="http://www.w3.org/2005/07/scxml">
      <xsl:template match="*">
        <xsl:copy>
          <xsl:copy-of select="attribute::*" />
          <xsl:apply-templates />
        </xsl:copy>
      </xsl:template>
      <xsl:template match="sc:data[@id = '{$data-id}']{$data-path}">
        <xsl:copy>
          <xsl:value-of select="{$expr}"/>
        </xsl:copy>
      </xsl:template>
    </xsl:stylesheet>
  
  return xdmp:xslt-eval($stylesheet, $datamodel)/sc:datamodel
};


(:
The spec at http://www.w3.org/TR/scxml/#script allows for either a src attribute or a text node, but not both. Trying 
to specify a module, its namespace, and a function name in a src attribute seems awkward, so for now, just supporting 
a text node, which is intended to be xdmp:eval'ed.
:)
declare function execute-script(
  $script as element(sc:script),
  $datamodel as element(sc:datamodel)
  ) as element(sc:datamodel)
{
  xdmp:eval(
    fn:string($script), 
    (xs:QName("datamodel"), $datamodel)
  )
};


declare function get-instance-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:instance-id/fn:string()
};


declare function get-machine-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:machine-id/fn:string()
};


declare function get-active-states($instance as element(mlsc:instance)) as xs:string*
{
  $instance/mlsc:active-states/mlsc:active-state/fn:string()
};
