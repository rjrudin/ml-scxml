package com.marklogic.scxml.datamodel;

import org.junit.Test;

import com.jayway.restassured.RestAssured;
import com.marklogic.scxml.AbstractScxmlTest;

public class AssignTest extends AbstractScxmlTest {

    @Test
    public void test() {
        RestAssured.post("/v1/resources/scxml");
    }
}
