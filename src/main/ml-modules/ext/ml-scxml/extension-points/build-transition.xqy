xquery version "1.0-ml";

module namespace mlscxp = "http://marklogic.com/scxml/extension-points";

declare namespace mlsc = "http://marklogic.com/scxml";
declare namespace sc = "http://www.w3.org/2005/07/scxml";


(:
Extension point for building a transition element. Can be overridden to include other items of interest.

ml-scxml doesn't depend on the transition elements at all, they're just there for history purposes.

Note that $exited states and $transition will be empty for a transaction that's executed when an instance starts up.
:)
declare function build-transition(
  $exited-states as element()*,
  $transition as element(sc:transition)?,
  $entered-states as element()+,
  $session as map:map  
  ) as element(mlsc:transition)
{
  element mlsc:transition {
    attribute transition-dateTime {fn:current-dateTime()},
    
    let $event := $transition/@event/fn:string()
    where $event
    return attribute event {$event},
    
    for $state in $exited-states
    let $id := $state/@id/fn:string()
    where $id
    return <mlsc:exit state="{$id}"/>,
    
    for $state in $entered-states
    let $id := $state/@id/fn:string()
    where $id
    return <mlsc:enter state="{$id}"/>
  }
};
