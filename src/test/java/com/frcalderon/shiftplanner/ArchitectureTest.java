package com.frcalderon.shiftplanner;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.dependencies.SlicesRuleDefinition.slices;

import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;

/**
 * Enforces the hexagonal dependency rule: infrastructure -> application -> domain.
 * <p>
 * Packages that are still empty are tolerated (see {@code archunit.properties}).
 * "No Lombok in domain/application" cannot be checked here: Lombok annotations have
 * source retention and are not present in the compiled classes.
 */
@AnalyzeClasses(packages = "com.frcalderon.shiftplanner", importOptions = ImportOption.DoNotIncludeTests.class)
class ArchitectureTest {

	@ArchTest
	static final ArchRule domainDoesNotDependOnOuterLayers = noClasses()
			.that().resideInAPackage("..domain..")
			.should().dependOnClassesThat().resideInAnyPackage("..application..", "..infrastructure..");

	@ArchTest
	static final ArchRule domainIsFrameworkFree = noClasses()
			.that().resideInAPackage("..domain..")
			.should().dependOnClassesThat().resideInAnyPackage(
					"org.springframework..", "jakarta.persistence..", "org.hibernate..");

	@ArchTest
	static final ArchRule applicationDoesNotDependOnInfrastructure = noClasses()
			.that().resideInAPackage("..application..")
			.should().dependOnClassesThat().resideInAPackage("..infrastructure..");

	@ArchTest
	static final ArchRule inboundAdaptersDoNotDependOnOutboundAdapters = noClasses()
			.that().resideInAPackage("..adapter.in..")
			.should().dependOnClassesThat().resideInAPackage("..adapter.out..");

	@ArchTest
	static final ArchRule contextsAreFreeOfCycles = slices()
			.matching("com.frcalderon.shiftplanner.(*)..")
			.should().beFreeOfCycles();

}
