package Web::App::Lib::EntityCollection;

use Class::Easy;

sub entity_collection_from_params {
	my $class  = shift;
	my $app    = shift;
	my $params = shift;
	
	my $entity_type = delete $params->{entity};
	# deprecated
	$entity_type = delete $params->{entity_type}
		unless defined $entity_type;
	
	critical "no entity type defined by controller param entity(_type)?"
		unless defined $entity_type;
	
	my $collection_pack = $app->project->collection ($entity_type);
	my $collection      = $collection_pack->new;
	
	if ($params->{fieldset}) {
		my $method = "fieldset_$params->{fieldset}";
		my $record = $collection_pack->record_package;
		critical "can't use fieldset $params->{fieldset} because no ${record}->$method method available"
			unless $record->can ($method);
		$collection->fieldset ($record->$method);
	} else {
		my $method = "fieldset_default";
		my $record = $collection_pack->record_package;
		$collection->fieldset ($record->$method)
			if $record->can ($method);
	}
	
	return $collection;
}

sub statement_from_params {
	my $class  = shift;
	my $app    = shift;
	my $params = shift;
	
	# allowed: filter.* => where, group_by, sort.(field|order) => sort_(field|order)
	#          limit, offset
	
	my $result = {where => {}};
	
	foreach my $k (%$params) {
		if ($k =~ /^group_by$/) {
			$result->{$k} = $params->{$k}
		} elsif ($k =~ /^sort\.(field|order)$/) {
			$result->{"sort_$1"} = $params->{$k}
		} elsif ($k =~ /^filter\.(.*)$/) {
			$result->{where}->{$1} = $params->{$k};
		}
	}
	
	return $result;
}

sub records {
	my $class  = shift;
	
	my $collection = $class->entity_collection_from_params (@_);
	my $statement  = $class->statement_from_params (@_);
	
	my $list = $collection->records (%$statement);
	
	return $list;
}

sub page {
	my $class  = shift;

	my $collection = $class->entity_collection_from_params (@_);
	my $statement  = $class->statement_from_params (@_);

	my $app    = shift;
	my $params = shift;
	
	my $count = $collection->count ($statement->{where});

	# by default i want 20 last records ordered by primary key
	
	my $page_num = $params->{num} || 1;
	
	$statement->{limit}  = $params->{length} || 20;
	$statement->{offset} = ($page_num - 1) * $statement->{limit};
	
	# When using LIMIT, it is important to use an ORDER BY clause that
	# constrains the result rows into a unique order. Otherwise you will
	# get an unpredictable subset of the query's rows. You might be asking
	# for the tenth through twentieth rows, but tenth through twentieth
	# in what ordering? The ordering is unknown, unless you specified ORDER BY.
	$statement->{sort_field} = $collection->_pk_
		unless $statement->{sort_field};

	$statement->{sort_order} = 'desc'
		unless $statement->{sort_order};
	
	# check for overflow
	if ($count < $statement->{offset}) {
		# TODO: return 404
		$statement->{offset} = 0;
	}
	
	if (300 < $statement->{limit}) {
		# TODO: return 404
		$statement->{limit} = 20;
	}
	
	my $list = $collection->records (%$statement);
	
	my $paging = {
		page_size     => $statement->{limit},
		count         => $count,
		page_num      => $page_num,
		pages_to_show => $params->{pager_size} || 8
	};

	my $pager = $collection->pager ($paging);
	
	return {
		items => $list,
		total_count => $count,
		version => 1,
		pager => $pager
	};
}


1;
