package com.marklogic.scxml.execcontent;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class ExecuteScriptOnEntryTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("on-entry-script");

        Response r = fireEvent(instanceId, "e");
        assertResponseHasInstanceIdAndState(r, instanceId, "s1");

        Instance i = loadInstance(instanceId);
        i.assertCurrentState("s1");
        i.assertDatamodelElementExists("ticket", "newElement[. = 'This was inserted via a script block']");

        String testXml = RestAssured.get("/v1/documents?uri=/ml-scxml/test/123.xml").asString();
        parse(testXml)
                .assertElementExists("Verifying that the script function inserted a test document", "/helloWorld");
    }
}
