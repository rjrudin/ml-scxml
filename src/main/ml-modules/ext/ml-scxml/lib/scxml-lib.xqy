xquery version "1.0-ml";

(:
This library is intended to not perform any persistence operations; it just implements SCXML functionality.
:)

module namespace mlsc = "http://marklogic.com/scxml";

import module namespace mlscxp = "http://marklogic.com/scxml/extension-points" at "/ext/ml-scxml/extension-points/build-transition.xqy";

declare namespace sc = "http://www.w3.org/2005/07/scxml";

declare function start(
  $machine-id as xs:string,
  $machine as element(sc:scxml),
  $instance-id as xs:string
  ) as element(mlsc:instance)
{
  (:
  TODO Support initial element too
  :)
  let $initial-state := ($machine/(sc:state|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]
  
  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:active-states {
      element mlsc:active-state {fn:string($initial-state/@id)}
    },
    
    (:
    TODO I can't tell for sure, but I think it's possible to have a datamodel under scxml and a datamodel under one 
    or more states. But each data element I believe must have a unique ID. So we can toss them all into a single datamodel
    on the instance document.
    :)
    let $data := $machine//sc:datamodel/sc:data
    where $data
    return element sc:datamodel { $data }
  }
  
  return enter-states($initial-state, (), $machine, $instance)
};


declare function handle-event(
  $instance as element(mlsc:instance),
  $machine as element(sc:scxml),
  $event as xs:string
  ) as element(mlsc:instance)
{
  let $current-state := $machine/element()[@id = get-active-states($instance)]
  
  (: 
  TODO Lots of matching logic to add here
  
  From the spec: "Compound states also affect how transitions are selected. When looking for transitions, the state 
  machine first looks in the most deeply nested active state(s), i.e., in the atomic state(s) that have no substates. 
  If no transitions match in the atomic state, the state machine will look in its parent state, then in the 
  parent's parent, etc. Thus transitions in ancestor states serve as defaults that will be taken if no 
  transition matches in a descendant state. If no transition matches in any state, the event is discarded." 
  :)
  let $transition := (
    $current-state/sc:transition[@event = $event],
    $current-state/sc:transition[@event = "*"]
  )[1]
  
  return
    if (fn:not($transition)) then
      fn:error(xs:QName("MISSING-TRANSITION"), "Could not find transition for event '" || $event || "'")
    else 
    
      let $target := fn:string($transition/@target)
      let $new-state := ($machine/sc:state[@id = $target], $machine/sc:final[@id = $target])[1]
      
      return
        if ($new-state) then 
          enter-states($new-state, $current-state, $machine, $instance)
          
        else
          (: Now look for a child state; assuming a state ID must be unique :)
          let $child-state := $machine//sc:state[@id = $target]
          return
            if ($child-state) then
              (: Gotta check for a parallel :)
              let $parallel := $child-state/ancestor::parallel
              return
                if ($parallel) then
                  (: Find the other states to enter in to :)
                  let $other-states := $parallel/sc:state[fn:not(@id = $target) and fn:not(.//sc:state[@id = $target])]
                  let $other-initial-states := 
                    (: TODO Support initial element too :)
                    for $other-state in $other-states
                    return $other-state/sc:state[@id = $other-state/@initial]
                  
                  return enter-states(($child-state, $other-initial-states), $current-state, $machine, $instance)
                  
                else
                  enter-states($child-state, $current-state, $machine, $instance)
                  
            else
              (: The spec says to just "discard" the event, but for now, throwing an error to signify an issue :)
              fn:error(xs:QName("MISSING-STATE"), "Could not find state '" || $target || "' to transition to for event '" || $event || "'")
};


declare function enter-states(
  $new-states as element()+,
  $current-state as element()?,
  $machine as element(sc:scxml), 
  $instance as element(mlsc:instance)
  ) as element(mlsc:instance)
{
  let $datamodel := $instance/sc:datamodel
  
  let $datamodel := execute-executable-content($current-state/sc:onexit/element(), $datamodel)
  let $datamodel := execute-executable-content($new-states/sc:onentry/element(), $datamodel)

  let $transitions := mlscxp:build-transition($new-states, $current-state, $machine, $instance) 
  
  let $new-active-states := 
    element mlsc:active-states { 
      for $state in $new-states
      return element mlsc:active-state {fn:string($state/@id)}
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


declare function get-active-states($instance as element(mlsc:instance)) as xs:string+
{
  $instance/mlsc:active-states/mlsc:active-state/fn:string()
};
