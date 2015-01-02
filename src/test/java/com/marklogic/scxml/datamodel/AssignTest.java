package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.response.Response;
import com.marklogic.scxml.AbstractScxmlTest;
import com.marklogic.scxml.Instance;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void test() {
        Response r = RestAssured.post("/v1/resources/scxml?rs:statechartId=assign");
        assertEquals(200, r.getStatusCode());
        assertEquals("application/json", r.getContentType());
        String instanceId = r.jsonPath().getString("instanceId");

        Instance i = loadInstance(instanceId);
        i.assertState("first");
        i.assertDatamodelElementExists("ticket", "price[. = '0']");
        i.prettyPrint();
    }
}
