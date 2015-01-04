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
  let $initial-state := ($machine/(sc:state|sc:final)[@id = $machine/@initial], $machine/sc:state[1])[1]
  
  let $instance := element mlsc:instance {
    attribute created-date-time {fn:current-dateTime()},
    element mlsc:machine-id {$machine-id},
    element mlsc:instance-id {$instance-id},
    element mlsc:state {fn:string($initial-state/@id)},
    $machine/sc:datamodel
  }
  
  return enter-state($initial-state, $machine, $instance)
};


declare function trigger-event(
  $instance as element(mlsc:instance),
  $machine as element(sc:scxml),
  $event as xs:string
  ) as element(mlsc:instance)
{
  let $state := $machine/element()[@id = $instance/mlsc:state/fn:string()]
  (: TODO Lots of matching logic to add here :)
  let $transition := $state/sc:transition[@event = $event][1]
  return
    if (fn:not($transition)) then
      fn:error(xs:QName("MISSING-TRANSITION"), "Could not find transition for event '" || $event || "'")
    else 
      let $target := fn:string($transition/@target)
      let $new-state := ($machine/sc:state[@id = $target], $machine/sc:final[@id = $target])[1]
      return
        if ($new-state) then 
          enter-state($new-state, $machine, $instance)
        else
          fn:error(xs:QName("MISSING-STATE"), "Could not find state '" || $target || "' to transition to")
};


declare function enter-state(
  $new-state as element(), 
  $machine as element(sc:scxml), 
  $instance as element(mlsc:instance)
  ) as element(mlsc:instance)
{
  let $datamodel := $instance/sc:datamodel
  let $_ := 
    for $el in $new-state/sc:onentry/element()
    return typeswitch ($el)
      case element(sc:log) return xdmp:log(xdmp:eval($el/@expr))
      case element(sc:assign) return xdmp:set($datamodel, execute-assign($el, $datamodel))
      default return ()

  let $transition := mlscxp:build-transition($instance, $machine, $new-state) 
    
  return element {fn:node-name($instance)} {
    $instance/@*,
    
    for $kid in $instance/element()
    return typeswitch($kid)
      case element(mlsc:state) return element mlsc:state {fn:string($new-state/@id)}
      case element(sc:datamodel) return $datamodel
      case element(mlsc:transitions) return 
        element mlsc:transitions {
          $kid/*,
          $transition
        }
      default return $kid,
      
    if (fn:not($instance/mlsc:transitions)) then 
      element mlsc:transitions {$transition}
    else ()
  }
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


declare function get-instance-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:instance-id/fn:string()
};


declare function get-machine-id($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:machine-id/fn:string()
};


declare function get-state($instance as element(mlsc:instance)) as xs:string
{
  $instance/mlsc:state/fn:string()
};
