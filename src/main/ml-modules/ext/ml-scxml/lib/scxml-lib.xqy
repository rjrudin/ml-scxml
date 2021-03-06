xquery version "1.0-ml";

(:
This library is intended to not perform any persistence operations; it just implements SCXML functionality.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlscxp = "http://marklogic.com/scxml/extension-points" at "/ext/ml-scxml/extension-points/build-transition.xqy";
import module namespace session = "http://marklogic.com/scxml/session" at "/ext/ml-scxml/lib/session-lib.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare variable $TRACE-EVENT := "ml-scxml";


(:
Start and return a new instance of the given machine definition.
:)
declare function start(
  $machine as element(sc:scxml),
  $instance-id as xs:string
  ) as element(mlsc:instance)
{
  xdmp:trace($TRACE-EVENT, "Starting machine with id " || $machine/@id),

  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    let $id := $machine/@id/fn:string()
    where $id
    return element mlsc:machine-id {$id},
    element mlsc:instance-id {$instance-id},
    element mlsc:current-states {},  
    let $data := $machine//sc:datamodel/sc:data
    where $data
    return element sc:datamodel { $data },
    element mlsc:transitions {}
  }
  
  let $session := session:new($instance, $machine, ())
   
  let $initial-state := ($machine/sc:initial, $machine/(sc:state|sc:parallel|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]

  let $entered-states := enter-state($initial-state, (), $session)
  
  let $_ := 
    for $state in $entered-states 
    return execute-default-transitions($state, $session)
  
  let $instance := session:get-instance($session)
  
  (: TODO Make convenience function for updating the instance with the new transition, can reuse here and in execute-transition :)
  return element mlsc:instance {
    $instance/@*,
    for $node in $instance/node()
    return typeswitch($node)
      case element(mlsc:transitions) return 
        element {fn:node-name($node)} {
          $node/@*,
          (: Put our "start" transition first, before default transitions that occurred as a result of the "start" transition :)
          mlscxp:build-transition((), (), $entered-states, $session),
          $node/node()
        }
      default return $node
  }
};


(:
Starts a new session and processes the given event, returning the updated (but not persisted) instance.
:)
declare function handle-event(
  $machine as element(sc:scxml),
  $instance as element(mlsc:instance),
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

TODO For logging the transaction, just show the target/event; logging the whole thing could get very verbose for
transactions with lots of executable content. 
:)
declare private function handle-next-event($session as map:map) as empty-sequence()
{
  let $event := session:get-current-event($session)
  where $event
  return 
  
    let $event-name := $event/name/fn:string()
    let $instance := session:get-instance($session)
    
    return (
      xdmp:trace($TRACE-EVENT, ("Handling event '" || $event-name || "' for instance " || get-instance-id($instance))),
      
      let $datamodel := get-datamodel($instance)
      let $transitioned-state-ids := ()
      
      let $executed-transitions := 
        for $t in find-candidate-transitions($event-name, $session)
        let $state := $t/..
        let $state-id := $state/@id/fn:string()
        let $already-transitioned-from-state := $state-id = $transitioned-state-ids
        return
          if ($already-transitioned-from-state) then
            xdmp:trace($TRACE-EVENT, ("Already executed a transition from state '" || $state-id || "', so ignoring", $t))
          else 
            let $already-executed-transition-for-child := $state//(sc:state|sc:parallel)/@id = $transitioned-state-ids
            return
              if ($already-executed-transition-for-child) then 
                xdmp:trace($TRACE-EVENT, ("A transition was already executed for a child state, so ignoring", $t))
              else
                let $result := evaluate-transition($t, $datamodel)
                return
                  if ($result) then (
                    xdmp:trace($TRACE-EVENT, ("Transition evaluated to true, so executing", $t)),
                    execute-transition($t, $state, $session),
                    xdmp:set($transitioned-state-ids, ($transitioned-state-ids, $state-id)),
                    $t
                  )
                  else
                    xdmp:trace($TRACE-EVENT, ("Transition evaluated to false, so ignoring", $t))
      
      where fn:not($executed-transitions)
      return xdmp:trace($TRACE-EVENT, ("Discarding event '" || $event-name || "'; could not find transition for it")),
      
      session:remove-current-event($session),
      
      handle-next-event($session)
    )
};


declare private function find-candidate-transitions(
  $event-name as xs:string,
  $session as map:map
  ) as element(sc:transition)*
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  let $current-state-ids := get-current-state-ids($instance)
  
  return (
    $machine//sc:transition[@event = $event-name and ../@id = $current-state-ids],
    $machine//sc:transition[@event = "*" and ../@id = $current-state-ids] 
  )
};

  
(:
Return true if the transition has no "cond" attribute or if that attribute evaluates to true, false otherwise.
:)
declare private function evaluate-transition(
  $t as element(sc:transition),
  $datamodel as element(sc:datamodel)?
  ) as xs:boolean
{
  let $cond := $t/@cond/fn:string()
  return
    if ($cond) then 
      evaluate-conditional($t, $datamodel)
    else
      fn:true()
};


(:
Execute a transition, updating the instance in the session map.

"2) if any compound <state> is in the set and none of its children is in the set, its default initial state(s) are added to the set"
"Any state whose child(ren) are added to the complete target set by clause 2 is called a default entry state"
:)
declare private function execute-transition(
  $transition as element(sc:transition),
  $source-state as element(),
  $session as map:map
  ) as empty-sequence()
{
  let $instance := session:get-instance($session)
  let $machine := session:get-machine($session)
  let $current-states := session:get-current-states($session)
  let $target := fn:string($transition/@target)
  
  let $_ := xdmp:trace($TRACE-EVENT, "Executing transition with target " || $target || " for instance " || get-instance-id($instance))
  
  let $target-state := $machine//(sc:state|sc:final)[@id = $target]
  
  let $states-to-exit := find-states-to-exit($source-state, $target-state, $current-states)
  let $states-to-enter := find-states-to-enter($source-state, $target-state)
  
  let $_ :=
    for $state in $states-to-exit
    return exit-state($state, $session)

  let $_ := execute-executable-content($transition/element(), $session)
  
  let $entered-states := ()
  let $_ :=  
    for $state in $states-to-enter
    where fn:not($state/@id = $entered-states/@id/fn:string())
    return 
      (: TODO Should we do "handle-final-state" as part of enter-state? I think we should :)
      let $states := enter-state($state, $target, $session)
      return xdmp:set($entered-states, ($entered-states, $states))
  
  let $_ := handle-final-states($entered-states, $session)
  
  let $transitions := mlscxp:build-transition($states-to-exit, $transition, $entered-states, $session)
  
  let $instance := session:get-instance($session)
  
  let $_ := session:set-instance($session, 
    element {fn:node-name($instance)} {
      $instance/@*,
      
      for $kid in $instance/element()
      return typeswitch($kid)
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
  )

  (: Execute default transitions for any states we entered. :)
  let $_ := execute-default-transitions($entered-states, $session)
  
  return ()
};


(:
For the given source and target states, return a sequence of states that should be exited.

TODO Initial elements pose a problem here because they don't allow an "id" attribute, but that's what we're using for
finding the LCCA and then finding states to exit.
:)
declare function find-states-to-exit(
  $source-state as element(), 
  $target-state as element(), 
  $current-states as xs:string*
  ) as element()*
{
  xdmp:trace($TRACE-EVENT, "Finding states to exit for source state '" || $source-state/@id || "' and target state '" || $target-state/@id || "'"),
  
  let $lcca := find-lcca-state(($source-state, $target-state))
  
  let $source-parent as element() :=
    if ($source-state instance of element(sc:initial)) then 
      $source-state/..
    else
      let $source-id := fn:string($source-state/@id) 
      return $lcca/(sc:state|sc:initial|sc:parallel)[@id = $source-id or .//sc:state/@id = $source-id]

  (:
  If the source parent is a compound state and we're transitioning from one child state to another, don't
  exit the parent state.
  :)
  let $is-compound-parent-of-both-source-and-target :=
    $source-parent instance of element(sc:state) and
    $source-parent//element()[@id = $target-state/@id]
  
  where fn:not($is-compound-parent-of-both-source-and-target)
  
  return fn:reverse((
    $source-parent,
    $source-parent//sc:state[@id = $current-states]
  ))
};


(:
For the given source and target state, return a sequence of states to enter.
:)
declare function find-states-to-enter(
  $source-state as element(), 
  $target-state as element()
  ) as element()*
{
  let $lcca := find-lcca-state(($source-state, $target-state))
  let $target-id := fn:string($target-state/@id)
  let $target-parent as element() := $lcca/(sc:state|sc:parallel|sc:final)[@id = $target-id or .//sc:state/@id = $target-id]
  let $target-parent-kids := $target-parent//sc:state[exists(.//sc:state[@id = $target-id])]
  
  (: If we're entering a parallel, ensure we return all child states :)
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


(:
Return the Least Common Compound Ancestor of the given states.
See http://www.w3.org/TR/scxml/#LCCA
:)
declare function find-lcca-state($states as element()+) as element()
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
Enter a state, returning a sequence of all states that were actually entered (in the case of a parallel or compound
state, we'll most likely return multiple states.
:)
declare private function enter-state(
  $state as element(), 
  $transition-target as xs:string?,
  $session as map:map
  ) as element()+
{
  xdmp:trace($TRACE-EVENT, "Entering state: " || $state/@id),
  
  let $_ := (
    session:add-current-states($session, $state/@id/fn:string()),
    execute-executable-content($state/sc:onentry/element(), $session)
  )
  
  return (
    $state,
    
    let $initial-state := 
      let $id := $state/@initial/fn:string()
      return 
        if ($id) then $state/element()[@id = $id]
        else $state/sc:initial
    where $initial-state
    return 
      if ($transition-target) then 
        (: We don't want to go to the initial state in a compound state if our transition target is some other child state in that compound target. :)
        let $non-target-initial := exists($state/element()[@id = $transition-target]) and fn:not($initial-state/@id = $transition-target)
        where fn:not($non-target-initial)
        return enter-state($initial-state, $transition-target, $session)
      else
        enter-state($initial-state, $transition-target, $session)
  )
};


(:
For each state that was entered, execute a default transition if it exists, updating the instance in the given
session.
:)
declare private function execute-default-transitions(
  $entered-states as element()+,
  $session as map:map
  ) as empty-sequence()
{
  for $state in $entered-states
  let $default-transition := $state/sc:transition[fn:not(@cond) and fn:not(@event)][1]
  where $default-transition
  return (
    xdmp:trace($TRACE-EVENT, "Executing default transition for state " || $state/@id),
    execute-transition($default-transition, $state, $session)
  )
};


(:
Exit the given state, updating the session as needed.
:)
declare private function exit-state(
  $state as element(),
  $session as map:map
  ) as empty-sequence()
{
  xdmp:trace($TRACE-EVENT, "Exiting state: " || $state/@id),
  execute-executable-content($state/sc:onexit/element(), $session),
  session:remove-current-states($session, $state/@id/fn:string())
};


(:
For each final state, raise a "done" event, and then determine if a parent parallel state has been 
closed as well, in which case raise a "done" event for it as well.
:)
declare private function handle-final-states(
  $entered-states as element()*,
  $session as map:map
  ) as empty-sequence()
{
  let $instance := session:get-instance($session)
  let $instance-id := get-instance-id($instance)
  
  for $state in $entered-states[self::sc:final]
  let $parent := $state/..[self::sc:state]
  where $parent
  return (
    add-internal-event($parent, $session),
    
    let $parallel := $parent/..[self::sc:parallel]
    where $parallel
    return
      let $instance := session:get-instance($session)
      let $current-states := session:get-current-states($session)
      let $current-final-id := fn:string($state/@id)
      let $final-states := $parallel/sc:state/sc:final
      let $final-states-not-yet-reached := 
        for $state in $final-states
        where fn:not(fn:string($state/@id) = ($current-states, $current-final-id))
        return $state
      where fn:not($final-states-not-yet-reached)
      return (
        add-internal-event($parallel, $session),
        
        (: Exit the final states in order :)
        for $state in $final-states
        return exit-state($state, $session),
        
        (: And then exit the parent states in order :)
        for $state in $final-states
        return exit-state($state/.., $session)
      ) 
  )
};


(:
Add a new internal event to the session.
:)
declare private function add-internal-event(
  $state as element(),
  $session as map:map
  ) as empty-sequence()
{
  let $event-name := "done.state." || $state/@id
  return (
    xdmp:trace($TRACE-EVENT, "Raising event " || $event-name || " for instance " || get-instance-id(session:get-instance($session))),
    session:add-event($session, $event-name, "internal")
  )
};


(:
Execute each of the given executable elements, updating the given session as needed.
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
      case element(sc:raise) return execute-raise($el, $session)
      case element(sc:if) return execute-if($el, $session)
      default return ()
  
  return ()
};


declare private function execute-if(
  $if as element(sc:if),
  $session as map:map
  ) as empty-sequence()
{
  let $instance := session:get-instance($session)
  let $datamodel := get-datamodel($instance)
  
  return
    if (evaluate-conditional($if, $datamodel)) then 
      execute-conditional-content($if, 1, $session)
    else
      let $executed := fn:false()
      
      for $el at $index in $if/element()
      where fn:not($executed) and ($el instance of element(sc:elseif) or $el instance of element(sc:else))
      return
        let $result :=
          if ($el instance of element(sc:else)) then fn:true()
          else evaluate-conditional($el, $datamodel)
        where $result
        return (
          xdmp:set($executed, fn:true()),
          execute-conditional-content($if, $index + 1, $session)
        )
};


declare private function evaluate-conditional(
  $el as element(),
  $datamodel as element(sc:datamodel)?
  ) as xs:boolean
{
  let $cond := $el/@cond/fn:string()
  return
    if ($cond) then 
      let $vars := 
        for $data in $datamodel/sc:data
        let $id := fn:string($data/@id)
        return (xs:QName($id), $data)
    
      let $xquery := text {
        'xquery version "1.0-ml"; ',
        for $data in $datamodel/sc:data
        let $id := fn:string($data/@id)
        return 'declare variable $' || $id || ' external; ',
        $cond
      }
      
      return (
        xdmp:trace($TRACE-EVENT, "Executing xquery for conditional element: " || $xquery),
        xdmp:eval($xquery, $vars)
      )
      
    else (
      xdmp:trace($TRACE-EVENT, ("No 'cond' attribute found in element, so returning false for it", $el)),
      fn:false()
    )
};


declare private function execute-conditional-content(
  $if as element(sc:if),
  $start as xs:integer,
  $session as map:map
  ) as empty-sequence()
{
  let $els := $if/element()[$start to fn:last()]
  let $partition := (
    for $el at $index in $els
    where $el instance of element(sc:elseif) or $el instance of element(sc:else)
    return $index,
    count($els)
  )[1]
  
  for $el in $els[1 to $partition]
  return execute-executable-content($el, $session)
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


declare private function execute-raise(
  $raise as element(sc:raise),
  $session as map:map
  ) as empty-sequence()
{
  let $event := fn:string($raise/@event)
  where $event
  return (
    xdmp:trace($TRACE-EVENT, "Raising event " || $event || " on instance " || get-instance-id(session:get-instance($session))), 
    session:add-event($session, $event, "external")
  )
};


declare function get-instance-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:instance-id/fn:string()
};


declare function get-machine-id($instance as element(mlsc:instance)) as xs:string?
{
  $instance/mlsc:machine-id/fn:string()
};


declare function get-current-state-ids($instance as element(mlsc:instance)) as xs:string*
{
  $instance/mlsc:current-states/mlsc:current-state/fn:string()
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

