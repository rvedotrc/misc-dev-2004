#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use warnings;
use strict;

@ARGV = "$ENV{HOME}/.mozilla/default/0brut3g4.slt/panacea.dat";
$/ = undef;
$_ = <>;

# c = column space, a = atom space.  Implied in that order.
# $.. = hex byte
# \ escapes \ $ )
# ( ) delimits cell

# ^ = hex ID.
# 	optional ":scope" where scope can be ^HEXID (in column space)
# 						or just NAME

# cell is: (column=value)

# row is: "[" rowid cell* "]" - EXCEPTION TODO
# rowid is: id, default scope is same row scope as enclosing table

my $p = {};
zm_Start($p) or die;
exit;

# zm:Start   ::= zm:Magic zm:LineEnd zm:Header (zm:Content | zm:Group)*
sub zm_start
{
	my $p = shift;
	$p->{magic} = zm_Magic($p) or die;
	zm_LineEnd($p) or die;
	zm_Header($p) or die;

	for (;;)
	{
		last if $_ eq "";
		zm_Content($p) or zm_Group($p) or die;
	}
}
# zm:Magic   ::= '// <!-- <mdb:mork:z v="1.1"/> -->'
sub zm_Magic
{
	my $p = shift;
	s#\A// <!-- <mdb:mork:z v="([\d\.]*)"/> -->## or return;
	{ version => $1 };
}
# zm:Header  ::= '@[' zm:S? zm:Id zm:RowItem* zm:S? ']@' /* file row */
sub zm_Header
{
	my $p = shift;
	s/\A\@\[// or return;
	zm_S();
	my $id = zm_Id();
	my @rows;
	while (my $row = zm_RowItem())
	{
	}
}
# zm:Content ::= (zm:Dict | zm:Table | zm:Update)*

# zm:S ::= (#x20 | #x9 | #xA | #xD | zm:Continue | zm:Comment)+ /* space */

# zm:LineEnd  ::= #xA #xD | #xD #xA | #xA | #xD /* 1 each if possible */
sub zm_LineEnd
{
	my $p = shift;
	s/\A(?:\012\015|\015\012|\012|\015)// or return;
	1;
}
# zm:NonCRLF ::= [#x0 - #xFF] - (#xD | #xA)
# zm:Comment  ::= '//' zm:NonCRLF* zm:LineEnd /* C++ style comment */
# zm:Continue ::= '\' zm:LineEnd

# zm:Hex   ::= [0-9a-fA-F] /* a single hex digit */
# zm:Id    ::= zm:Hex+     /* a row, table, or value id is naked hex */

# zm:AnyRef    ::= zm:TableRef | zm:RowRef | zm:ValueRef
# zm:TableRef  ::= zm:S? 't' zm:Id
# zm:RowRef    ::= zm:S? 'r' zm:Id
# zm:ValueRef  ::= zm:S? '^' zm:Id /* use '^' to avoid zm:Name ambiguity */

# zm:MoreName  ::= [a-zA-Z:_+-?!]
# zm:Name      ::= [a-zA-Z:_] zm:MoreName*
# /* names only need to avoid space and '^', so this is more limiting */

# zm:Update  ::= zm:S? [!+-] (zm:Row | zm:Table)
# /* +="<mdb:add/>" (insert) -="<mdb:cut/>" (remove) !="<mdb:put/>" (set) */

# /* groups must be ignored until properly terminated */
# zm:Group       ::= zm:GroupStart zm:Content zm:GroupEnd /* transaction */
# zm:GroupStart  ::= zm:S? '@$${' zm:Id '{@' /* transaction id has own space */
# zm:GroupEnd    ::= zm:GroupCommit | zm:GroupAbort
# zm:GroupCommit ::= zm:S? '@$$}' zm:Id '}@'  /* id matches start id */
# zm:GroupAbort  ::= zm:S? '@$$}~abort~' zm:Id '}@' /* id matches start id */
# /* We must allow started transactions to be aborted in summary files. */
# /* Note '$$' will never occur unescaped in values we will see in Mork. */

# zm:Dict      ::= zm:S? '<' zm:DictItem* zm:S? '>'
# zm:DictItem  ::= zm:MetaDict | zm:Alias
# zm:MetaDict  ::= zm:S? '<' zm:S? zm:Cell* zm:S? '>' /* meta attributes */
# zm:Alias     ::= zm:S? '(' zm:Id zm:S? zm:Value ')'

# zm:Table     ::= zm:S? '{' zm:S? zm:Id zm:TableItem* zm:S? '}'
# zm:TableItem ::= zm:MetaTable | zm:RowRef | zm:Row
# zm:MetaTable ::= zm:S? '{' zm:S? zm:Cell* zm:S? '}' /* meta attributes */

# zm:Row       ::= zm:S? '[' zm:S? zm:Id zm:RowItem* zm:S? ']'
# zm:RowItem   ::= zm:MetaRow | zm:Cell
# zm:MetaRow   ::= zm:S? '[' zm:S? zm:Cell* zm:S? ']' /* meta attributes */

# zm:Cell      ::= zm:S? '(' zm:Column zm:S? zm:Slot? ')'
# zm:Column    ::= zm:S? (zm:Name | zm:ValueRef)
# zm:Slot      ::= zm:Value | zm:AnyRef zm:S?

# zm:Value   ::= '=' ([^)] | '\' zm:NonCRLF | zm:Continue | zm:Dollar)*
# /* content ')', '\', and '$' must be quoted with '\' inside zm:Value */
# zm:Dollar  ::= '$' zm:Hex zm:Hex /* hex encoding of one byte */
# /* using '$' instead of '%' helps avoid the need to quote URL markup */

