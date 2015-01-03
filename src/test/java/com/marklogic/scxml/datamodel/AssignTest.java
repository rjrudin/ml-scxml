package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.path.json.JsonPath;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void test() {
        String instanceId = startMachineWithId("assign");

        Instance i = loadInstance(instanceId);
        i.assertmachineId("assign");
        i.assertInstanceId(instanceId);
        i.assertState("first");
        i.assertDatamodelElementExists("ticket", "price[. = '0']");

        Response r = postToService("rs:instanceId=" + instanceId + "&rs:event=e");
        assertEquals(200, r.getStatusCode());
        JsonPath json = r.jsonPath();
        assertEquals(instanceId, json.getString("instanceId"));
        assertEquals("s1", json.getString("state"));

        i = loadInstance(instanceId);
        i.assertState("s1");
        i.assertDatamodelElementExists("ticket", "price[. = '10']");
        i.prettyPrint();
    }
}
