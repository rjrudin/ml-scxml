package com.marklogic.scxml.execcontent;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteOnExitTest extends AbstractScxmlTest {

    /**
     * onexit shouldn't be any different from onentry, so we just verify that an assign and a script works here.
     */
    @Test
    public void assignAndScript() {
        String instanceId = startMachineWithId("on-exit-with-assign-and-script");

        Response r = fireEvent(instanceId, "e");
        assertResponseHasInstanceIdAndState(r, instanceId, "s1");

        Instance i = loadInstance(instanceId);
        i.assertCurrentState("s1");
        i.assertDatamodelElementExists("ticket", "price[. = '10']");
        i.assertDatamodelElementExists("ticket", "newElement[. = 'This was inserted via a script block']");

        String testXml = RestAssured.get("/v1/documents?uri=/ml-scxml/test/123.xml").asString();
        parse(testXml)
                .assertElementExists("Verifying that the script function inserted a test document", "/helloWorld");
    }

    /**
     * TODO Might be nice to retain history of the datamodel? Otherwise we lose the fact that the onexit assignment
     * happened, which changed the price to 10.
     */
    @Test
    public void assignOnExitAndAssignOnEntry() {
        String instanceId = startMachineWithId("on-exit-assign-and-on-entry-assign");

        Response r = fireEvent(instanceId, "e");
        assertResponseHasInstanceIdAndState(r, instanceId, "s1");

        Instance i = loadInstance(instanceId);
        i.assertCurrentState("s1");
        i.assertDatamodelElementExists("ticket", "price[. = '20']");
    }
}
