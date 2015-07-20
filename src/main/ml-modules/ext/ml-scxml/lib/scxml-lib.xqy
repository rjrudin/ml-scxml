xquery version "1.0-ml";

(:
This library is intended to not perform any persistence operations; it just implements SCXML functionality.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlscxp = "http://marklogic.com/scxml/extension-points" at "/ext/ml-scxml/extension-points/build-transition.xqy";
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

  let $active-states := (
    $initial-state/@id/fn:string(),
    enter-initial-states($initial-state)
  )
   
  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:active-states {
      for $state in $active-states
      return element mlsc:active-state {$state}
    },
    
    let $data := $machine//sc:datamodel/sc:data
    where $data
    return element sc:datamodel { $data }
  }
  
  return enter-states($initial-state, (), (), session:new($instance, $machine, ()))
};


declare private function enter-initial-states($state as element()) as xs:string*
{
  let $initial := $state/@initial/fn:string()
  let $child-state := $state/element()[@id = $initial]
  where $initial and $child-state
  return (
    $child-state/@id/fn:string(),
    enter-initial-states($child-state)
  )
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


declare function get-datamodel($instance as element(mlsc:instance)) as element(sc:datamodel)?
{
  $instance/sc:datamodel
};


declare function rebuild-with-new-datamodel(
  $instance as element(mlsc:instance),
  $new-datamodel as element(sc:datamodel)
  ) as element(mlsc:instance)
{
  element mlsc:instance {
    $instance/@*,
    for $kid in $instance/node()
    return
      if ($kid instance of element(sc:datamodel)) then $new-datamodel
      else $kid
  }
};


(:
Gets the current event, and if one exists, processes it (which means find all the states that have transitions with
that event, and execute each matching transition, updating the instance document as we go), then remove the current
event, then call handle-next-event in case one or more events were added.
:)
declare private function handle-next-event($session as map:map) as empty-sequence()
{
  let $event := session:get-current-event($session)
  where $event
  return 
  
    let $event-name := $event/name/fn:string()
    let $instance := session:get-instance($session)
    let $machine := session:get-machine($session)
    
    let $_ := xdmp:trace($TRACE-EVENT, ("Handling event '" || $event-name || "' for instance " || get-instance-id($instance)))
  
    let $current-states := $machine//(sc:state|sc:initial|sc:parallel)[@id = get-active-states($instance)]
    
    return (
      let $executed-transitions := 
        for $current-state in $current-states 
        let $transition := (
          $current-state/sc:transition[@event = $event-name],
          $current-state/sc:transition[@event = "*"]
        )[1]
        where $transition
        return (
          session:set-instance($session, execute-transition($transition, $current-state, $session)),
          $transition
        )
      
      where fn:not($executed-transitions)
      return xdmp:trace($TRACE-EVENT, ("Discarding event '" || $event-name || "'; could not find transition for it")),
      
      session:remove-current-event($session),
      
      handle-next-event($session)
    )
};


(:
This implementation assumes that initial/state/final IDs are unique. I can't think of a good reason for them not to be,
and things would get very confusing if they weren't.

So when we execute a transition, we first need to determine all the states that are exited and all the states that will
be entered. And then we fire the
onExit block for each of those. Then we remove each of those states from the set of active states on the instance. 
Then we fire the executable content for each transition. And then we enter each of the new states, adding them to the
instance, and invoking onEntry for each of them.
:)
declare private function execute-transition(
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
              
              return enter-states(($parallel, $new-state, $other-initial-states), $current-state, $transition, $session)
            else
              enter-states($new-state, $current-state, $transition, $session)
          
        else
          enter-states($new-state, $current-state, $transition, $session)
          
    else
      (: The spec says to just "discard" the event, but for now, throwing an error to signify an issue :)
      fn:error(xs:QName("MISSING-STATE"), "Could not find state '" || $target || "' to transition to for event '" || $transition/@event || "'")
};


declare private function enter-states(
  $new-states as element()+,
  $current-state as element()?,
  $transition as element(sc:transition)?,
  $session as map:map
  ) as element(mlsc:instance)
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  
  let $_ := xdmp:trace($TRACE-EVENT, "Entering state(s) '" || fn:string-join($new-states/@id, ",") || "' for instance " || get-instance-id($instance))
  
  let $states-to-remove := 
    (: According to the example in 3.1.3 of the spec, we raise an event for the parent state when we reach the final child state :)
    for $final-state in $new-states[self::sc:final]
    let $parent := $final-state/..[self::sc:state]
    where $parent
    return 
      let $parent-event-name := "done.state." || $parent/@id
      return (
        xdmp:trace($TRACE-EVENT, "Raising event " || $parent-event-name || " for instance " || get-instance-id($instance)),
        session:add-event($session, $parent-event-name, "internal"),
        
        (: If this is part of a parallel, and all other parts are final, then raise an event for the parallel too :)
        let $parallel := $parent/..[self::sc:parallel]
        where $parallel
        return
        
          let $final-state-ids := $parallel/sc:state/sc:final/@id/fn:string()
          let $active-states := $instance/mlsc:active-states/mlsc:active-state/fn:string()
          let $current-final-id := fn:string($final-state/@id)
          let $unfinished-state-ids := 
            for $state-id in $final-state-ids
            where fn:not($state-id = ($active-states, $current-final-id))
            return $state-id
          
          where fn:not($unfinished-state-ids)
          return
            (: When we close out a parallel, we need to remove the child final IDs from the set of active states :) 
            let $parallel-event-name := "done.state." || $parallel/@id
            return (
              xdmp:trace($TRACE-EVENT, "Raising event " || $parallel-event-name || " for instance " || get-instance-id($instance)),
              session:add-event($session, $parallel-event-name, "internal"),
              $final-state-ids
            )
      )
  
  let $states-to-retain := $instance/mlsc:active-states/mlsc:active-state[fn:not(. = $current-state/@id) and fn:not(. = $states-to-remove)]
  
  let $new-active-states := 
    element mlsc:active-states {
      $states-to-retain,
      for $state in $new-states
      let $id := fn:string($state/@id)
      where fn:not($id = $states-to-retain/fn:string()) and fn:not($id = $states-to-remove)
      return element mlsc:active-state {$id}
    }
  
  let $transitions := mlscxp:build-transition($new-states, $current-state, $transition, $session) 
  
  (: TODO Fix this order; should be onexit, transition, onentry :)
  let $_ := execute-executable-content($current-state/sc:onexit/element(), $session)
  let $_ := execute-executable-content($new-states/sc:onentry/element(), $session)
  let $instance := session:get-instance($session)
  
  return element {fn:node-name($instance)} {
    $instance/@*,
    
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:active-states) return $new-active-states
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


declare private function execute-executable-content(
  $executable-content-elements as element()*,
  $session as map:map
  ) as empty-sequence()
{
  let $_ := 
    for $el in $executable-content-elements
    return typeswitch ($el)
      case element(sc:log) return xdmp:log(xdmp:eval($el/@expr))
      case element(sc:assign) return execute-assign($el, $session)
      case element(sc:script) return execute-script($el, $session)
      default return ()
  
  return ()
};


(:
Using XSLT to transform the datamodel based on the location and expression in the assign block. Don't yet know a way to
do this in just XQuery.
:)
declare private function execute-assign(
  $assign as element(sc:assign),
  $session as map:map
  ) as empty-sequence()
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
  
  let $instance := session:get-instance($session)
  let $datamodel := get-datamodel($instance)
  let $new-datamodel := xdmp:xslt-eval($stylesheet, $datamodel)/sc:datamodel
  return session:set-instance(
    $session,
    rebuild-with-new-datamodel($instance, $new-datamodel)
  )
};


(:
The spec at http://www.w3.org/TR/scxml/#script allows for either a src attribute or a text node, but not both. Trying 
to specify a module, its namespace, and a function name in a src attribute seems awkward, so for now, just supporting 
a text node, which is intended to be xdmp:eval'ed.
:)
declare private function execute-script(
  $script as element(sc:script),
  $session as map:map
  ) as empty-sequence()
{
  xdmp:eval(
    fn:string($script), 
    (xs:QName("session"), $session)
  )
};


