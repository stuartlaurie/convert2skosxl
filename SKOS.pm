package SKOS;

use 5.010000;
use strict;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Zthes ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

## flag to xml encode when passing through the clean_term routine
our $xml_encode=0;
our $debug_level=1;
our $base_uri;
our %structure;
our %terms;
our %labels;
our %relationships;
our %properties;

our %property_types = (
	'altLabel' => 'http://www.w3.org/2008/05/skos-xl#altLabel',
	'prefLabel' => 'http://www.w3.org/2008/05/skos-xl#prefLabel',
	'related' => 'http://www.w3.org/2004/02/skos/core#related',
	'has broader' => 'http://www.w3.org/2004/02/skos/core#broader',
	'has narrower' => 'http://www.w3.org/2004/02/skos/core#narrower',
	'scope note' => 'http://www.w3.org/2004/02/skos/core#scopeNote',
);

our %structure_lookup;
$structure_lookup{class}{Concept}="http://www.w3.org/2004/02/skos/core#Concept";

our %reverse_lookup;
our %duplicate_labels;
our %model_stats;

##****************************************************************************************************************************************************************
## Sets some basic defaults for output, model name and zthes ID prefix
##****************************************************************************************************************************************************************
#####################################################################################################
## model name - string - name of the model
## prefix - string - base URI
#####################################################################################################

sub set_defaults{
   my ($name,$prefix)=@_;
   if ($debug_level eq 0){ warn "Setting Model name: $name\n"; }
   $structure{model_name}=$name;
   if ($debug_level eq 0){ warn "Setting Zthes ID prefix: $prefix\n"; }
   $base_uri="$prefix";   
}

sub add_model_comment{
	my ($comment)=shift @_;
	$structure{comment}=$comment;
}

##****************************************************************************************************************************************************************
## Routines for building the ontology structure
##****************************************************************************************************************************************************************

#########################################################
## routine to add a class and optionally a parent class
#########################################################
# SKOS::structure_addclass(Class Name,Language,Parent Class (Optional));
#########################################################

sub structure_addclass{
	my ($class, $language, $parentclass_uri)=@_;
	warn "Trying to add Class: $class, $language, $parentclass_uri\n";
	
	## set base URI
	my $URI=clean_uri($base_uri,$structure{model_name},$class);
	
	## check if URI exists and warn
	if (exists $structure_lookup{class}{$URI}){
		warn "Class $class already exists with ID: $structure_lookup{class}{$class}\n"; 
	}
	else{
	    $model_stats{Classes}++;	
		warn "Adding class to Model: $class ($URI)\n"; 
		$structure{classes}{$URI}{name}=$class;
		$structure{classes}{$URI}{language}=$language;
		
		## if no parent class defined then declare as subclass to concept
		if ($parentclass_uri eq ""){
			$structure{classes}{$URI}{parentclass}="http://www.w3.org/2004/02/skos/core#Concept";
		}
		## else, check parent class exists and use parent class
		else{
			if (exists $structure{classes}{$parentclass_uri}{name}){
				warn "Adding class $class as sub-class to parent $parentclass_uri\n";
				$structure{classes}{$URI}{parentclass}=$parentclass_uri;
			}
			else{
				warn "Parent class of uri $parentclass_uri does not exist in model structure\n"; 
			}
		}
		$structure_lookup{class}{$class}=$URI;
		
	}
	return $structure_lookup{class}{$class};
}

#########################################################
## routine to add relationships
#########################################################
# SKOS::structure_addrelationship(Class Name,Language,Parent Class (Optional));
#########################################################

sub structure_addrelationshiptype{
	my ($type, $language, $forward, $reverse, $domain, $range)=@_;
	if ($debug_level eq 1){ warn "Adding relationship to Model: $type, $language, $domain: $forward -> $range: $reverse, \n"; }
	
	my $inverse_uri;
	
	## set base URI
	my $URI=clean_uri($base_uri,$structure{model_name},$forward);
	
	## add in defaults
	$structure{relationship}{$URI}{name}=$forward;
	$structure{relationship}{$URI}{language}=$language;
	
	## add relationship to allowed values list
	$property_types{$forward}=$URI;
	
	## store lookup of existing relationships
	$structure_lookup{relationships}{$forward}=$URI;
	$model_stats{RelationshipTypes}++;
	
	## check domain assigned and assign as default if none specicfied
	if ($domain ne ""){
		if (exists $structure_lookup{class}{$domain}){
			warn "Setting domain to: $domain\n";
			$structure{relationship}{$URI}{domain}=$structure_lookup{class}{$domain};
		}
		else{
			warn "Class $domain does not exist in model structure\n"; 
		}
	}
	else{
		warn "No domain specified, setting to default\n";
		$structure{relationship}{$URI}{domain}="http://www.w3.org/2004/02/skos/core#Concept";
	}
	
	## add in relationship type specific information
	if ($type eq "related"){
		$structure{relationship}{$URI}{type}="http://www.w3.org/2004/02/skos/core#related";
		## check range assigned and assign as default if none specicfied
		if ($range ne ""){
			if (exists $structure_lookup{class}{$range}){
				warn "Setting range to: $domain\n";
				$structure{relationship}{$URI}{range}=$structure_lookup{class}{$range};
			}
			else{
				warn "Class $range does not exist in model structure\n"; 
			}
		}
		else{
			warn "No domain specified, setting to default\n";
			$structure{relationship}{$URI}{domain}="http://www.w3.org/2004/02/skos/core#Concept";
		}
		## add reverse relationship
		unless (exists $structure_lookup{relationships}{$reverse}){
			SKOS::structure_addrelationshiptype($type,$language,$reverse,$forward,$range,$domain);
		}
		$structure{relationship}{$URI}{inverse}=$structure_lookup{relationships}{$reverse};
	}
	elsif ($type eq "altLabel"){
		$structure{relationship}{$URI}{type}="http://www.w3.org/2008/05/skos-xl#altLabel";
		$structure{relationship}{$URI}{range}="http://www.w3.org/2008/05/skos-xl#Label";
	}	
	elsif ($type eq "labelRelation"){
		$structure{relationship}{$URI}{type}="http://www.w3.org/2008/05/skos-xl#skosxl:LabelRelation";
		$structure{relationship}{$URI}{range}="http://www.w3.org/2008/05/skos-xl#Label";
		$structure{relationship}{$URI}{domain}="http://www.w3.org/2008/05/skos-xl#Label";
	}
	else{
		warn "Relationship Type not valid, use 'related' or 'altLabel'\n"; 
	}
	
	return $structure_lookup{relationships}{$forward};
}

#########################################################
## routine to add datatype properties
#########################################################
# Zthes::structure_adddatatype(Type, Name, Language, Class);
#########################################################

sub structure_adddatatype{
	my ($type,$name,$language,$class) = @_;
	
	## set base URI
	my $URI=clean_uri($base_uri,$structure{model_name},$name);
	
	$property_types{$name}=$URI;
	
	if (exists $structure_lookup{datatypes}{$name}){
        if ($debug_level eq 1){ warn "Datatype exists, not adding: $name\n"; }
	}
	else{
		if ($debug_level eq 1){ warn "Adding Datatype Property to Model: $name, $type, $language, $class\n"; }
		$structure{datatypes}{$URI}{name}=$name;
		$structure{datatypes}{$URI}{language}=$language;
		if ($class ne ""){
			if (exists $structure_lookup{class}{$class}){
				warn "Setting domain to: $class\n";
				$structure{datatypes}{$URI}{domain}=$structure_lookup{class}{$class};
			}
			else{
				warn "Class $class does not exist in model structure\n"; 
			}
		}
		else{
			warn "No domain specified, setting to default\n";
			$structure{datatypes}{$URI}{domain}="http://www.w3.org/2004/02/skos/core#Concept";
		}
		$structure_lookup{datatypes}{$name}=$URI;
	}
	
	## set correct range (dataype)
	if ($type eq "string"){
		$structure{datatypes}{$URI}{range}="xsd:string";
	}
	elsif ($type eq "boolean"){
		$structure{datatypes}{$URI}{range}="xsd:boolean";
	}
	else{
		warn "Datatype Type not valid, use 'boolean' or 'string'\n";
	}
	
	$model_stats{DatatypeProperties}++;
	return  $structure_lookup{datatypes}{$name};
}

#####################################################################################################
## Stores concept scheme
#####################################################################################################

sub add_conceptScheme{
	my ($term_id,$term_name,$language)=@_;
	
	if ($debug_level eq 1){ warn "\nTrying to add Concept Scheme: $term_name ($term_id), Language: $language\n"; }
	
	if ($term_id eq ""){
		my $URI="ConceptScheme/".$term_name;
		$term_id=clean_uri($base_uri,$structure{model_name},$URI);
	}
	$terms{conceptSchemes}{$term_id}{name}=$term_name;
	$terms{conceptSchemes}{$term_id}{language}=$language;
	$terms{conceptSchemes}{$term_id}{type}="http://www.w3.org/2004/02/skos/core#ConceptScheme";
	
	if ($debug_level eq 1){ warn "ConceptScheme added: $term_name ($term_id), Language: $language\n"; }
	$model_stats{ConceptSchemes}++;

	return $term_id;
} 


#####################################################################################################
## Stores concept information 
#####################################################################################################

sub add_concept{
	my ($term_id,$term_name,$language,$term_class)=@_;
  
	if ($debug_level eq 1){ warn "\nTrying to add concept: $term_name ($term_id), Language: $language, Class: $term_class\n"; }
 	
	## if name specified
	if ($term_name ne ""){
		## if no id specified then generate URI from name
		if ($term_id eq ""){
			$term_id=clean_uri($base_uri,$structure{model_name},$term_name);
		}
		else{
			$term_id=clean_uri($base_uri,$structure{model_name},$term_id);
		}
		## warn if duplicate
		if ($reverse_lookup{$term_name}){
			if ($debug_level eq 1){ warn "Term already exists: $term_name, Language: $language Class: $term_class\n"; }
		}

		$terms{concepts}{$term_id}{name}=$term_name;
		$terms{concepts}{$term_id}{language}=$language;
		
		SKOS::add_label($term_id,"$term_name",$language,"prefLabel");
		
		if ($term_class ne ""){
			if (exists $structure_lookup{class}{$term_class}){
				warn "Setting range to: $term_class\n";
				$terms{concepts}{$term_id}{type}=$structure_lookup{class}{$term_class};
			}
			else{
				warn "Class $term_class does not exist in model structure\n"; 
			}
		}
		else{
			warn "No class specified, setting to default\n";
			$terms{concepts}{$term_id}{type}="http://www.w3.org/2004/02/skos/core#Concept";
		}
		if ($debug_level eq 1){ warn "Concept added: $term_name ($term_id), Language: $language, Class: $term_class\n"; }
		$model_stats{Concepts}++;
	}	
	else{
		if ($debug_level eq 1){ warn "ERROR: Concept name is empty string\n"; }
	}
	
    return $term_id;
  
}

#####################################################################################################
## Routine to add labels
## uri_suffix can be used when adding labels that also have IDs that need displaying in the model 
## (basically first order NPTs)
#####################################################################################################

sub add_label{
	my ($concept_id,$term_label,$language,$label_type,$label_id,$uri_suffix)=@_;
	my $add_label=1;
  
	if ($debug_level eq 1){ warn "\nTrying to add label: $term_label, Language: $language, label type: $label_type\n"; }
 	
	## check name specified
	unless ($term_label ne ""){
		if ($debug_level eq 1){ warn "ERROR: label is empty string\n"; }
		$add_label=0;
	}
	
	## check label type
	unless (exists $property_types{$label_type}){
		if ($debug_level eq 1){ warn "label type not valid $label_type, use one of %property_types\n"; }
		$add_label=0;
	}

	## warn if duplicate
	if ($reverse_lookup{$term_label}){
		if ($debug_level eq 1){ warn "Term already exists: $term_label, Language: $language\n"; }
	}	
	
	## warn if exact duplicate
	if (exists $duplicate_labels{$concept_id}{$label_type}{$term_label}{$language}){
		if ($debug_level eq 1){ warn "Label is exact duplicate: $term_label, Language: $language\n"; }
		$add_label=0;
	}

	if ($add_label eq 1){
		
		if ($label_id eq ""){
			$label_id=clean_altlabel_uri($concept_id,$term_label,$language,$uri_suffix);
		}
		else{
			$label_id=clean_altlabel_uri($concept_id,$label_id,$language,$uri_suffix)
		}

		$labels{$label_id}{name}=$term_label;
		$labels{$label_id}{language}=$language;		
		$labels{$label_id}{type}=$property_types{$label_type};		
		
		## create hash for duplicate checking
		$duplicate_labels{$concept_id}{$label_type}{$term_label}{$language}++;
		
		if (exists $terms{concepts}{$concept_id}{labels}){ 
			$terms{concepts}{$concept_id}{labels}.=";".$label_id;
		}
		else{
			$terms{concepts}{$concept_id}{labels}=$label_id;
		}
			
		if ($debug_level eq 1){ warn "label added: $term_label ($label_id), Language: $language, label type: $label_type\n"; }
		$model_stats{Labels}++;
	}
  
	return $label_id;
  
}


#####################################################################################################
## Routine to add relationships for a term
#####################################################################################################


sub add_relationship{

    my ($source_term_id, $target_term_id, $relationship_type) = @_;

   # if ($debug_level eq 1){ warn "\nTrying to create relationship from $source_term_id ($terms{concepts}{$source_term_id}{name}) to $target_term_id ($terms{concepts}{$target_term_id}{name}) using $relationship_type\n"; }

	## check label type
	unless (exists $property_types{$relationship_type}){
		if ($debug_level eq 1){ warn "label type not valid $relationship_type, use one of %property_types\n"; }
	}
	$relationship_type=$property_types{$relationship_type};
	
    #if(exists $terms{concepts}{$source_term_id}{name} and exists $terms{concepts}{$target_term_id}{name}){
      if ($relationship_type ne ""){
        if ($source_term_id eq $target_term_id){
     #      if ($debug_level eq 1){ warn "Relationship target and source ids are same: $source_term_id, $target_term_id cannot create relationship\n"; }
        }
        else{
          if ($relationships{$source_term_id}{relationship}{$relationship_type}{target_id} eq $target_term_id){
      #      if ($debug_level eq 1){ warn "Relationship already exists: $source_term_id to: $target_term_id using relationship type: $relationship_type\n"; }
          }
          else{

       #       if ($debug_level eq 1){ warn "Adding relationship from: $source_term_id ($terms{concepts}{$source_term_id}{name}) to: $target_term_id ($terms{concepts}{$target_term_id}{name}) using relationship type: $relationship_type\n"; }
              $relationships{$source_term_id}{relationship}{$relationship_type}{target_id}.=$target_term_id.";";
              $relationships{$source_term_id}{relationship}{$relationship_type}{rel_id}=$source_term_id.$target_term_id.$relationship_type;
			  $model_stats{Relationships}++;
		  }
        
        }  
      
      }
	  else{
         if ($debug_level eq 1){ warn "WARNING: No Relationship Type Specified\n"; }
	  }

    #}
    #else{
	   # unless (exists $terms{concepts}{$source_term_id}{name} ){
	      #if ($debug_level eq 1){ warn "WARNING: Source Term: $source_term_id does not exist\n"; }
	   # }
	   # unless (exists $terms{concepts}{$target_term_id}{name} ){
	       # if ($debug_level eq 1){ warn "WARNING: Target Term: $target_term_id does not exist\n"; }
	   # }	   

       #delete $terms{$target_term_id};
    #}
	return $source_term_id.$target_term_id.$relationship_type;
}


#####################################################################################################
## Routine to store properties for a concept
#####################################################################################################

##  <http://example.com/Test_Export#Deprecated> "true"^^xsd:boolean ;
##  <http://example.com/Test_Export#Market-Capitalization> "$48 Billion"@en ;

sub add_string_property{
	my ($concept_id, $metadata_type, $metadata_value, $language) = @_;
  
	if ($debug_level eq 1){ warn "Trying to add Metadata: $metadata_value, Metadata Type: $metadata_type, Term: $terms{concepts}{$concept_id}{name}\n"; }
	$metadata_value=~s/\n/<br>/g;
	$metadata_value=~s/"/<br>/g;
	
	if ($metadata_value ne ""){
	
	$metadata_value=qq("$metadata_value")."\@".$language;  
  
	unless (exists $property_types{$metadata_type}){
		if ($debug_level eq 1){ warn "label type not valid $metadata_type, use one of %property_types\n"; }
	}
	$metadata_type=$property_types{$metadata_type}; 
  
	if (exists $properties{$concept_id}{$metadata_type}){
		$properties{$concept_id}{$metadata_type}.=";;".$metadata_value;
	}
	else{
		$properties{$concept_id}{$metadata_type}=$metadata_value;
	}
    $model_stats{Properties}++;
	}
}


#####################################################################################################
## Helper routine to convert non XML characters and remove extra spaces etc
#####################################################################################################

sub clean_term{
   my ($dirty_term,$xml_encode)=@_;
   $dirty_term =~ s/"//g;
   $dirty_term=~ s/ +$//;
   $dirty_term=~ s/^ +//;
   $dirty_term =~ s/\s+$//;
   $dirty_term =~ s/^\s+//;
   if ($xml_encode eq 1){
	$dirty_term =~ s/&/&amp;/g;
	$dirty_term =~ s/</&lt;/g;
	$dirty_term =~ s/>/&gt;/g;
	$dirty_term =~ s/'/&apos;/g;   
	$dirty_term =~ s/"/&quot;/g; 
   }
   return $dirty_term;
}

sub clean_uri{
   my ($base_uri,$model_name,$name)=@_;
   $name =~ s/ /-/g;
   my $URI=$base_uri.$model_name."#".$name;
   return $URI;
}

sub clean_altlabel_uri{
	my ($base_uri,$name,$language,$uri_suffix)=@_;
	my $URI="";
	
	$name =~ s/ /-/g;
	$name =~ s/\W//g;
	if ($uri_suffix ne ""){
		$URI=$base_uri."/".$uri_suffix."/".$name."_".$language;
	}
	else{
		$URI=$base_uri."/".$name."_".$language;
	}
	return $URI;
}

sub check_length{
   my ($string,$validlength)=@_;
   my $length=length($string);
   if ($debug_level eq 1){ warn "Length: " + $length; }
   if ($length>$validlength){
    if ($debug_level ge 0){ warn "ERROR: String longer than $validlength characters, shortening\n$string"; }
    $string=substr($string,0,$validlength);
	my $semicolon_index=rindex($string,';');
	my $ampersand_index=rindex($string,'&');
	if ($ampersand_index ne 0 and $semicolon_index < $ampersand_index){
	  if ($debug_level eq 1){ warn "ERROR: String has unescaped XML character"; }
	  $string=substr($string,0,($ampersand_index-1));
	}
   }
   return $string;
}   

sub strip_xml{
	my ($string)=shift @_;
	$string=~s/<.*?>//g;
	$string=clean_term($string);
	return $string;
}


#####################################################################################################
## Get id for Term - checks to see if a term with a specific name already exists
#####################################################################################################

sub get_id_for_term{
  my ($term_name,$term_class)=@_;
  
  if ($debug_level eq 1){ warn "Checking if name exists: $term_name, in class: $term_class\n"; }
  
  $term_name=clean_term($term_name,$xml_encode);  
 
  warn $reverse_lookup{$term_name}{$term_class};
 
  if ($reverse_lookup{$term_name}{$term_class}){
    return $reverse_lookup{$term_name}{$term_class};
  }
  else{
    return;
  }
} 


#####################################################################################################
## Print out the data
#####################################################################################################

sub print_data{

	my $output_file=shift @_;
	warn "Writing out model data to $output_file\n";
	open (OUT, ">".$output_file) || die "Can't open $output_file: $!\n";
	binmode OUT, ':utf8';

#####################################################################################################
## Print ttl headers
#####################################################################################################  

	print OUT qq(# baseURI: urn:x-evn-master:$structure{model_name}\n); ## TODO: What should this be?
	print OUT qq(# imports: http://www.smartlogic.com/2014/08/semaphore-core\n);
	print OUT qq(\n);
	print OUT qq(\@prefix owl: <http://www.w3.org/2002/07/owl#> .\n);
	print OUT qq(\@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n);
	print OUT qq(\@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n);
	print OUT qq(\@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n);
	print OUT qq(\n);
	
	print OUT qq(<urn:x-evn-master:$structure{model_name}>\n);
	print OUT qq(  rdf:type <http://topbraid.org/teamwork#Vocabulary> ;\n);
	print OUT qq(  rdf:type owl:Ontology ;\n);
	if ($structure{comment} ne ""){
		print OUT qq(  rdfs:comment "$structure{comment}" ;\n);
	}
	print OUT qq(  <http://spinrdf.org/spin#imports> <http://www.smartlogic.com/2015/02/semaphore-spin-constraints> ;\n);
	print OUT qq(  <http://spinrdf.org/spin#imports> <http://www.smartlogic.com/2015/12/unique-concept-label-constraint> ;\n);
	print OUT qq(  <http://spinrdf.org/spin#imports> <http://www.smartlogic.com/2015/12/unique-concept-label-in-class-constraint> ;\n);
	print OUT qq(  owl:imports <http://www.smartlogic.com/2014/08/semaphore-core> ;\n);
	print OUT qq(.\n\n);

#####################################################################################################
## Output Classes
##################################################################################################### 

	foreach my $class_uri (sort keys %{$structure{classes}}){
		print OUT qq(<$class_uri>\n);
		print OUT qq(  rdf:type owl:Class ;\n);
		print OUT qq(  rdfs:label "$structure{classes}{$class_uri}{name}"\@$structure{classes}{$class_uri}{language} ;\n);
		print OUT qq(  rdfs:subClassOf <$structure{classes}{$class_uri}{parentclass}> ;\n);
		print OUT qq(.\n\n);
	}
  
#####################################################################################################
## Output Relationships 
#####################################################################################################

	foreach my $relationship_uri (sort keys %{$structure{relationship}}){
		
		print OUT qq(<$relationship_uri>\n);
		print OUT qq(  rdf:type owl:ObjectProperty ;\n);
		print OUT qq(  rdfs:label "$structure{relationship}{$relationship_uri}{name}"\@$structure{relationship}{$relationship_uri}{language} ;\n);
		print OUT qq(  rdfs:domain <$structure{relationship}{$relationship_uri}{domain}> ;\n);
		print OUT qq(  rdfs:range <$structure{relationship}{$relationship_uri}{range}> ;\n);
		print OUT qq(  rdfs:subPropertyOf <$structure{relationship}{$relationship_uri}{type}> ;\n);
		if (exists $structure{relationship}{$relationship_uri}{inverse}){
			print OUT qq(  owl:inverseOf <$structure{relationship}{$relationship_uri}{inverse}> ;\n);
		}
		print OUT qq(.\n\n);
	}
  
#####################################################################################################
## Output Datatype Properties (notes, boolean etc)
#####################################################################################################  
  
    foreach my $datatype_uri (keys %{$structure{datatypes}}){ 
		print OUT qq(<$datatype_uri>\n);
		print OUT qq(  rdf:type owl:DatatypeProperty ;\n);
		print OUT qq(  rdfs:domain <$structure{datatypes}{$datatype_uri}{domain}> ;\n);
		print OUT qq(  rdfs:label "$structure{datatypes}{$datatype_uri}{name}"\@$structure{datatypes}{$datatype_uri}{language} ;\n);
		print OUT qq(  rdfs:range $structure{datatypes}{$datatype_uri}{range} ;\n);
		print OUT qq(.\n\n);
	}
  
#####################################################################################################
## Output Concept schemes
#####################################################################################################  

	foreach my $uri (keys %{$terms{conceptSchemes}}){ 
		print OUT qq(<$uri>\n);
		print OUT qq(  rdf:type <$terms{conceptSchemes}{$uri}{type}> ;\n);
		print OUT qq(  rdfs:label "$terms{conceptSchemes}{$uri}{name}"\@$terms{conceptSchemes}{$uri}{language} ;\n);
		if ($terms{conceptSchemes}{$uri}{guid} ne ""){
			print OUT qq(  <http://www.smartlogic.com/2014/08/semaphore-core#guid> "$terms{conceptSchemes}{$uri}{guid}" ;\n);
		}
		## Narrower Terms
		foreach my $relationship_type (sort {$a <=> $b} keys %{$relationships{$uri}{relationship}}){
			my @ids=split(/;/,$relationships{$uri}{relationship}{$relationship_type}{target_id});
			foreach my $related_id (@ids){
				print OUT qq(  <http://www.w3.org/2004/02/skos/core#hasTopConcept> <$related_id> ;\n);
			}	  
		}
		print OUT qq(.\n\n);
	}

#####################################################################################################
## Output Concepts
#####################################################################################################  

	foreach my $uri (keys %{$terms{concepts}}){
		print OUT qq(<$uri>\n);
		print OUT qq(  rdf:type <$terms{concepts}{$uri}{type}> ;\n);
		# print OUT qq(  skos:prefLabel "$terms{concepts}{$uri}{name}"\@$terms{concepts}{$uri}{language} ;\n);
		## Labels
		# <http://www.w3.org/2008/05/skos-xl#prefLabel> <http://example.com/Test_Export#Smartlogic/Smartlogic_en> ;
		# <http://www.w3.org/2008/05/skos-xl#altLabel> <http://example.com/Test_Export#Stuart-Laurie/stulaurie_en> ;
		# <http://example.com/Test_Export#Has-Ticker> <http://example.com/Test_Export#Smartlogic/SLK_en>
		
		my @labels=split(/;/,$terms{concepts}{$uri}{labels});
		foreach my $label_uri (@labels){
			print OUT qq( <$labels{$label_uri}{type}> <$label_uri> ;\n);
		}
		
		if ($terms{concepts}{$uri}{guid} ne ""){
			print OUT qq(  <http://www.smartlogic.com/2014/08/semaphore-core#guid> "$terms{concepts}{$uri}{guid}" ;\n);
		}
		
		## Notes
		# <http://example.com/Test_Export#Market-Capitalization> "$48 Billion"@en ;
		
		foreach my $property (sort keys %{$properties{$uri}}){
			my @notes=split(/;;/,$properties{$uri}{$property});
			foreach my $note (@notes){
				print OUT qq( <$property> $note ;\n);
			}
		}
		
		## Relationships
		# <http://example.com/Test_Export#Employee-of> <http://example.com/Test_Export#Smartlogic> ;
		foreach my $relationship_type (sort {$a <=> $b} keys %{$relationships{$uri}{relationship}}){
			my @ids=split(/;/,$relationships{$uri}{relationship}{$relationship_type}{target_id});
			foreach my $related_id (@ids){
				print OUT qq(  <$relationship_type> <$related_id> ;\n);
			}	  
		}
		print OUT qq(.\n\n);
	}

#####################################################################################################
## Output labels
##################################################################################################### 

	foreach my $uri (keys %labels){
		print OUT qq(<$uri>\n);
		print OUT qq(  rdf:type <http://www.w3.org/2008/05/skos-xl#Label> ;\n);
		print OUT qq(  <http://www.w3.org/2008/05/skos-xl#literalForm> "$labels{$uri}{name}"\@$labels{$uri}{language} ;\n);
		foreach my $relationship_type (sort {$a <=> $b} keys %{$relationships{$uri}{relationship}}){
			my @ids=split(/;/,$relationships{$uri}{relationship}{$relationship_type}{target_id});
			foreach my $related_id (@ids){
				print OUT qq(  <$relationship_type> <$related_id> ;\n);
			}	  
		}
		print OUT qq(.\n\n);
	}
  
#####################################################################################################
## Close file
##################################################################################################### 
  
	close(OUT);
  
#####################################################################################################
## Print stats
#####################################################################################################   
  
  print "Term Stats:\n";
  foreach my $stat (sort keys %model_stats){
     print "$stat: $model_stats{$stat}\n";
  }
}


# Preloaded methods go here.

1;


__END__


# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Zthes - Perl extension for creating Zthes format taxonomy files

=head1 SYNOPSIS

  use Zthes;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Zthes, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>a.u.thor@a.galaxy.far.far.awayE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
