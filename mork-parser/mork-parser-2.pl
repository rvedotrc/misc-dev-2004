#!/usr/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

use Parse::RecDescent;


#/* see separate post for summary of 1.0 -> 1.1 syntax changes for */
#
#/* mdb="abstract mail/news db interfaces, also known by nsIMsgDb" */
#/* mork="summary file format defining mdb reference implementation" */
#/* z="zany mongrel Mork terse syntax roughly inspired by Lisp" */
#/* x="XML style Mork verbose syntax embeddable in XML documents" */
#/* l="Lisp style Mork paren syntax for hypothetical comparisons" */
#/* Start="starting production for a Mork document" */
#
#/* <production-suffixes XmlMork="xm" LispMork="lm" ZanyMork="zm"/> */

my $grammar = <<'EOF';

<autotree>

zm_Hex   : /[0-9a-fA-F]/ /* a single hex digit */
			{ $item[1] }
zm_OldId    : zm_Hex(s)     /* a row, table, or value id is naked hex */
			{ join "", @{ $item[1] } }
zm_Id    : zm_OldId ( /:/ zm_Scope { $item[2] } )(?)
			{ my %r = ( id => $item[1] );
			$r{scope} = $item[2][0] if $item[2];
			delete $r{scope} unless $r{scope};
			bless \%r, "zm_Id" }
zm_Scope: zm_Name { $item[1] } | zm_ValueRef { $item[1] }

zm_S : (/[\x20\x09\x0A\x0D]/ | zm_Continue | zm_Comment)(s) /* space */
	{ "" }

zm_LineEnd  : /(\012\015|\015\012|\012|\015)/ /* 1 each if possible */
zm_NonCRLF : /[\x00-\x09\x0B\x0C\x0E-\xFF]/
zm_Comment  : /\/\// zm_NonCRLF(s?) zm_LineEnd /* C++ style comment */
zm_Continue : /\x5C/ zm_LineEnd
				{ "" }

zm_AnyRef    : zm_TableRef { $item[1] } | zm_RowRef { $item[1] } | zm_ValueRef { $item[1] }
zm_TableRef  : zm_S(?) /t/ zm_Id
				{ bless $item[3], "zm_TableRef" }
zm_RowRef    : zm_S(?) /r/ zm_Id
				{ bless $item[3], "zm_RowRef" }
zm_ValueRef  : zm_S(?) /\^/ zm_Id /* use '^' to avoid zm_Name ambiguity */
				{ bless $item[3], "zm_ValueRef" }

zm_MoreName  : /[a-zA-Z:_+?!-]/
				{ $item[1] }
zm_Name      : /[a-zA-Z:_]/ zm_MoreName(s?)
				{ my $s = $item[1] . join "", @{ $item[2] };
			 	bless \$s, "zm_Name" }
/* names only need to avoid space and '^', so this is more limiting */

zm_Update  : zm_S(?) ( zm_UpdateRow | ( /[!+-]/ (zm_Row | zm_Table) ) )
/* +="<mdb:add/>" (insert) -="<mdb:cut/>" (remove) !="<mdb:put/>" (set) */

/* groups must be ignored until properly terminated */

zm_Dict      : zm_S(?) /</ zm_DictItem(s?) zm_S(?) />/
				{ bless $item[3], "zm_Dict" }
zm_DictItem  : zm_MetaDict { $item[1] } | zm_Alias { $item[1] }
zm_MetaDict  : zm_S(?) /</ zm_S(?) zm_Cell(s?) zm_S(?) />/ /* meta attributes */
				{ bless $item[4], "zm_MetaDict" }
zm_Alias     : zm_S(?) /\(/ zm_Id zm_S(?) zm_Value /\)/
				{ bless { id => $item[3], value => $item[5] }, "zm_Alias" }

zm_Table     : zm_S(?) /{/ zm_S(?) zm_Id zm_TableItem(s?) zm_S(?) /}/
				{ bless { id => $item[4], items => $item[5] }, "zm_MetaTable" }
zm_TableItem : zm_MetaTable { $item[1] } | zm_RowRef { $item[1] } | zm_Row { $item[1] }
zm_MetaTable : zm_S(?) /{/ zm_S(?) zm_Cell(s?) zm_S(?) /}/ /* meta attributes */
				{ bless $item[4], "zm_MetaTable" }

zm_UpdateRow       : zm_S(?) /\[/ /[!+-]/ zm_S(?) zm_Id zm_RowItem(s?) zm_S(?) /\]/
zm_Row       : zm_S(?) /\[/ zm_S(?) zm_Id zm_RowItem(s?) zm_S(?) /\]/
				{ bless { id => $item[4], items => $item[5] }, "zm_Row" }
zm_RowItem   : zm_MetaRow { $item[1] } | zm_Cell { $item[1] }
zm_MetaRow   : zm_S(?) /\[/ zm_S(?) zm_Cell(s?) zm_S(?) /\]/ /* meta attributes */

zm_Cell      : zm_S(?) /\(/ zm_Column zm_S(?) zm_Slot(?) /\)/
				{ bless { column => $item[3], slot => $item[5] }, "zm_Cell" }
zm_Column    : zm_S(?) (zm_Name { $item[1] } | zm_ValueRef { $item[1] })
				{ $item[2] }
zm_Slot      : zm_Value { $item[1] } | zm_AnyRef zm_S(?) { $item[1] }

zm_Value   : /=/ (
			zm_Dollar
			| /\x5C/ zm_NonCRLF { $item[2] }
			| zm_Continue { "" }
			| /[^\)]/ { $item[1] }
			)(s?)
			{ my $s = join "", @{ $item[2] }; bless \$s, "zm_Value" }
/* content ')', '\', and '$' must be quoted with '\' inside zm_Value */
zm_Dollar  : /\$/ zm_Hex zm_Hex /* hex encoding of one byte */
			{ chr hex($item[2].$item[3]) }
/* using '$' instead of '%' helps avoid the need to quote URL markup */

zm_GroupStart  : zm_S(?) /\@\$\${/ zm_Id /{\@/ /* transaction id has own space */
					{ $item[3] }
zm_GroupCommit : zm_S(?) /\@\$\$}/ zm_Id /}\@/  /* id matches start id */
zm_GroupAbort  : zm_S(?) /\@\$\$}~abort~/ zm_Id /}\@/ /* id matches start id */
zm_GroupEnd    : zm_GroupCommit | zm_GroupAbort
/* We must allow started transactions to be aborted in summary files. */
/* Note '$$' will never occur unescaped in values we will see in Mork. */
zm_Group       : zm_GroupStart zm_Content zm_GroupEnd /* transaction */
				{ bless { id => $item[1], content => $item[2] }, "zm_Group" }

zm_Magic   : /\/\/\x20<!--\x20<mdb:mork:z\x20v="/ /1\.\d/ /"\/\>\x20--\>/
			{ +{ version => $item[2] } }
zm_Header  : /\@\[/ zm_S(?) zm_Id zm_RowItem(s?) zm_S(?) /\]\@/ /* file row */
zm_Content : (zm_Dict { $item[1] } | zm_Table { $item[1] } | zm_Update { $item[1] })(s?)
			{ $item[1] }
zm_Start   : zm_Magic zm_LineEnd zm_Header(?) (zm_Group | zm_Content)(s?) zm_S(?) zm_EOF

zm_EOF : /\z/

EOF

$grammar =~ s#\s*/\*.*?\*/$##mg;
$grammar =~ s#/\*.*?\*/##g;
#$grammar =~ s/\n\n+/\n/g;

$Parse::RecDescent::skip = '';
#print $grammar;
my $parser = Parse::RecDescent->new($grammar);

use Data::Dumper;
#print Data::Dumper->Dump([ $parser ],[ 'parser' ]);

my $rule = shift () || "zm_Start";

my $text = do { local $/; <> };
#$::RD_TRACE = 1;
my $r = $parser->$rule(\$text);
use Data::Dumper;
$Data::Dumper::Indent = 1;         # mild pretty print
print Data::Dumper->Dump([ $r, $text ],[ 'r', 'text' ]);

# eof mork-parser-2.pl
