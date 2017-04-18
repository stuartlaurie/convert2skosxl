###############################################################################################################
## Example program that creates an ontology using the SKOS modules
###############################################################################################################

use strict;
use SKOS;

##################################
## Define variables
##################################
## Output file names
my $output_skos_file="Test.ttl";

## some placeholders for IDs
my ($conceptSchemeId,$conceptId,$altLabelId);

## set defaults: Ontology Name, URI, Classes Enabled, Class Duplicates, Full Duplicates, Duplicate case check Multiple Relationships
SKOS::set_defaults("Test_Import","http://smartlogic.com/",1,0,1,0,0,0);

# add an rdfs:comment to the model - to describe creation
SKOS::add_model_comment("Created by Smartlogic");

###################################################################################
## Model Structure
###################################################################################

## add Class "Person" 
SKOS::structure_addclass("Person","en");

## add Class "Organization" 
my $classId=SKOS::structure_addclass("Organization","en");
my $noteId=SKOS::structure_adddatatype("string","Market Cap","en","Organization");

## add global note
my $noteId=SKOS::structure_adddatatype("boolean","Deprecated","en","");

## add Sub-Class "Listed Company" 
SKOS::structure_addclass("Listed Company","en",$classId);

## add a new associative relationship type
SKOS::structure_addrelationshiptype("related","en","Has Employee","Employee of","Organization","Person");

## add a new alternate label type
SKOS::structure_addrelationshiptype("altLabel","en","Has Ticker","","Organization","");

###################################################################################
## Concept Schemes, Concepts and Relationships
###################################################################################

## add Concept Scheme
my $conceptSchemeId=SKOS::add_conceptScheme("","Companies","en");

## add Concept
my $conceptId1=SKOS::add_concept("","Smartlogic","en","Organization");
SKOS::add_relationship($conceptSchemeId,$conceptId1,"has narrower");

## add Concept
my $conceptId2=SKOS::add_concept("","MarkLogic","en","Organization");
SKOS::add_relationship($conceptSchemeId,$conceptId2,"has narrower");

## add standard relationship
SKOS::add_relationship($conceptId1,$conceptId2,"related");

## add Concept Scheme
my $conceptSchemeId=SKOS::add_conceptScheme("","People","en");

## add Concept
my $conceptId3=SKOS::add_concept("","Stuart Laurie","en","Organization");
SKOS::add_relationship($conceptSchemeId,$conceptId3,"has narrower");

## add Concept
my $conceptId4=SKOS::add_concept("","Toby Conrad","en","Organization");
SKOS::add_relationship($conceptSchemeId,$conceptId4,"has narrower");

## add custom relationship
SKOS::add_relationship($conceptId3,$conceptId1,"Employee of");

###################################################################################
## Concept Labels
###################################################################################

## add altLabel
SKOS::add_label($conceptId1,"SL","en","altLabel");

## add custom altLabel
SKOS::add_label($conceptId1,"SLK","en","Has Ticker");

## add translation as altlabel
SKOS::add_label($conceptId1,"SLK","fr","altLabel");

## add different language prefLabel
SKOS::add_label($conceptId1,"Smartlogique","fr","prefLabel");

###################################################################################
## Concept properties
###################################################################################

SKOS::add_string_property($conceptId1,"scope note","a really interesting scope note","en");

SKOS::add_string_property($conceptId1,"Market Cap","\$1 billion dollars","en");


## write the output file
SKOS::print_data($output_skos_file);

