package com.frcalderon.shiftplanner;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.core.annotation.AliasFor;
import org.springframework.test.context.ActiveProfiles;

@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@SpringBootTest
@Import(TestcontainersConfiguration.class)
@ActiveProfiles("test")
public @interface IntegrationTest {

	@AliasFor(annotation = SpringBootTest.class)
	SpringBootTest.WebEnvironment webEnvironment() default SpringBootTest.WebEnvironment.MOCK;

}
