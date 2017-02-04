package com.marklogic.scxml;

import com.marklogic.junit.spring.BasicTestConfig;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.PropertySource;

@Configuration
@PropertySource({"file:gradle.properties"})
public class ScxmlTestConfig extends BasicTestConfig {

	@Override
	protected String buildContentDatabaseName(String mlAppName) {
		return mlAppName + "-content";
	}
}
