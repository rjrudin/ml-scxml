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
  xdmp:trace($TRACE-EVENT, "Starting machine with id " || $machine-id),

  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:active-states {},  
    let $data := $machine//sc:datamodel/sc:data
    where $data
    return element sc:datamodel { $data },
    element mlsc:transitions {}
  }
  
  let $session := session:new($instance, $machine, ())
   
  let $initial-state := ($machine/sc:initial, $machine/(sc:state|sc:parallel|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]

  let $entered-states := enter-state($initial-state, (), $session)
  
  let $instance := session:get-instance($session)
  
  return element mlsc:instance {
    $instance/@*,
    for $node in $instance/node()
    return typeswitch($node)
      case element(mlsc:active-states) return 
        element {fn:node-name($node)} {
          $node/@*,
          for $state in $entered-states
          return element mlsc:active-state {$state/@id/fn:string()}
        }
      case element(mlsc:transitions) return 
        element {fn:node-name($node)} {
          $node/@*,
          mlscxp:build-transition($entered-states, (), (), $session)
        }
      default return $node
  }
};

(:
Returns a sequence containing the ID of each state that was entered.
:)
declare private function enter-state(
  $state as element(), 
  $transition-target as xs:string?,
  $session as map:map
  ) as element()+
{
  xdmp:trace($TRACE-EVENT, "Entering state: " || $state/@id),
  
  let $_ := execute-executable-content($state/sc:onentry/element(), $session)
  
  return (
    $state,

    (: TODO Support initial element too :)
    let $initial := $state/@initial/fn:string()
    let $child-state := $state/element()[@id = $initial]
    where $initial and $child-state
    return 
      if ($transition-target) then 
        (: 
        We don't want to go to the initial state in a compound state if our transition target is some other state in
        that compound target.
        :)
        let $non-target-initial := exists($state/element()[@id = $transition-target]) and fn:not($child-state/@id = $transition-target)
        where fn:not($non-target-initial)
        return enter-state($child-state, $transition-target, $session)
      else
        enter-state($child-state, $transition-target, $session)
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

declare function find-states-to-exit($source-state, $target-state, $active-states)
{
  let $source-id := fn:string($source-state/@id)
  let $lcca := find-lcca-state(($source-state, $target-state))
  let $source-parent as element() := $lcca/(sc:state|sc:initial|sc:parallel)[@id = $source-id or .//sc:state/@id = $source-id]
  
  return fn:reverse((
    $source-parent,
    $source-parent//sc:state[@id = $active-states]
  ))
};


(:
If one of the states to enter is a parallel, then we need to grab all the child states of that
parallel that aren't already being selected.
:)
declare function find-states-to-enter($source-state, $target-state)
{
  let $lcca := find-lcca-state(($source-state, $target-state))
  let $target-id := fn:string($target-state/@id)
  let $target-parent as element() := $lcca/(sc:state|sc:parallel|sc:final)[@id = $target-id or .//sc:state/@id = $target-id]
  let $target-parent-kids := $target-parent//sc:state[exists(.//sc:state[@id = $target-id])]
  let $parallel-states := 
    if ($target-parent instance of element(sc:parallel)) then 
      $target-parent/sc:state[fn:not(@id = $target-parent-kids/@id/fn:string())]
    else ()
    
  return (
    $target-parent,
    $target-parent-kids,
    $parallel-states,
    $target-state
  )
};

declare function find-lcca-state($states as element()+)
{
  let $common-ancestors := $states[1]/ancestor::sc:state/@id/fn:string()
  
  let $_ := 
    for $state in $states[2 to fn:last()]
    let $these-ancestor-ids := $state/ancestor::sc:state/@id/fn:string()
    return xdmp:set($common-ancestors, $these-ancestor-ids[. = $common-ancestors])
  
  return (
    $states[1]/ancestor::sc:state[@id = $common-ancestors[fn:last()]],
    $states[1]/ancestor::sc:scxml
  )[1]
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
          session:set-instance($session, new-exec($transition, $current-state, $session)),
          $transition
        )
      
      where fn:not($executed-transitions)
      return xdmp:trace($TRACE-EVENT, ("Discarding event '" || $event-name || "'; could not find transition for it")),
      
      session:remove-current-event($session),
      
      handle-next-event($session)
    )
};


(:
So when we execute a transition, we first need to determine all the states that are exited and all the states that will
be entered. And then we fire the onExit block for each of those. Then we remove each of those states from the set of active states on the instance. 
Then we fire the executable content for each transition. And then we enter each of the new states, adding them to the
instance, and invoking onEntry for each of them.

TODO A transition can also be on a parallel element.
TODO A transition can have multiple target states.

"1) if any <parallel> element is a member of the set, any of its children that are not members of the set must be added "
"2) if any compound <state> is in the set and none of its children is in the set, its default initial state(s) are added to the set"
"Any state whose child(ren) are added to the complete target set by clause 2 is called a default entry state"
:)
declare private function new-exec(
  $transition as element(sc:transition),
  $source-state as element(),
  $session as map:map
  )
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  let $active-states := session:get-active-states($session)
  let $target := fn:string($transition/@target)
  
  let $_ := xdmp:trace($TRACE-EVENT, "Executing transition with target " || $target || " for instance " || get-instance-id($instance))
  
  let $target-state := $machine//(sc:state|sc:final)[@id = $target]
  
  (: 
  Now we need to figure out which states that we leave, and in what order, as that's important for onExit reasons.
  TODO Assuming external for now, need to implement internal as well.
  :)
  
  let $states-to-exit := find-states-to-exit($source-state, $target-state, $active-states)
  let $states-to-enter := find-states-to-enter($source-state, $target-state)
  
  (: EXIT STATES :)
  let $_ := (
    for $state in $states-to-exit
    let $_ := xdmp:trace($TRACE-EVENT, "Exiting state: " || $state/@id) 
    return execute-executable-content($state/sc:onexit/element(), $session),
    session:remove-active-states($session, $states-to-exit/@id/fn:string())
  )

  (: INVOKE TRANSITION LOGIC :)
  let $_ := execute-executable-content($transition/element(), $session)
  
  (: ENTER STATES :)
  let $entered-states := ()
  let $_ :=  
    for $state in $states-to-enter
    where fn:not($state/@id = $entered-states/@id/fn:string())
    return 
      let $states := enter-state($state, $target, $session)
      return xdmp:set($entered-states, ($entered-states, $states))
  
  let $_ := session:add-active-states($session, $entered-states/@id/fn:string())
  let $transitions := mlscxp:build-transition($entered-states, $source-state, $transition, $session)
  
  (: Now rewrite the instance based on our new active states and transitions :)
  let $instance := session:get-instance($session)
  
  return element {fn:node-name($instance)} {
    $instance/@*,
    
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:active-states) return 
        element mlsc:active-states {
          for $state in session:get-active-states($session)
          return element mlsc:active-state {$state}
        }
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


(:
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
:)


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


