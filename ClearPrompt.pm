package ClearCase::ClearPrompt;

require 5.004;

$VERSION = '1.13';
@ISA = qw(Exporter);
@EXPORT_OK = qw(clearprompt clearprompt_dir);
%EXPORT_TAGS = ( 'all' => [@EXPORT_OK] );

use strict;
require Exporter;

use constant MSWIN	=> $^O =~ /MSWin32|Windows_NT/i;

use Cwd;
use File::Spec;

sub ccpath
{
   my $name = shift;
   my @stds = map {File::Spec->catdir($_, 'bin')} MSWIN ?
	 qw(C:/Program Files/Rational/ClearCase C:/atria) : q(/usr/atria);
   for my $path (map {File::Spec->catdir($_, $name)} @_, @stds) {
      return $path if -x $path || -x "$path.exe";
   }
   return $name;
}

# Generates a name for a temp file which doesn't yet exist.
# This function makes no pretense of being atomic; i.e. it's
# conceivable - though highly unlikely - that the generated filename
# could be taken between the time it's generated and the time it's
# used.
# The optional parameter becomes a filename extension. The optional
# 2nd parameter overrides the basename part of the generated path.
sub tempname
{
   my($custom, $tmpf) = @_;
   my $ext = 'tmp';
   my $tmpd = MSWIN ?
	    ($ENV{TEMP} || $ENV{TMP} || ( -d "$ENV{SYSTEMDRIVE}/temp" ?
			      "$ENV{SYSTEMDRIVE}/temp" : $ENV{SYSTEMDRIVE})) :
	    ($ENV{TMPDIR} || '/tmp');
   $tmpd =~ s%\\%/%g;
   (my $pkg = lc __PACKAGE__) =~ s/:+/-/g;
   return "$tmpd/$tmpf.$custom.$ext" if $tmpf;
   while (1) {
      $tmpf = join('.', "$tmpd/$pkg", $$, int(rand 10000));
      $tmpf .= $custom ? ".$custom.$ext" : ".$ext";
      return $tmpf if ! -f $tmpf;
   }
}

# Run clearprompt with specified args and return what it returned. Uses the
# exact same syntax as the clearprompt executable ('ct man clearprompt')
# except for the -outfile flag, which is handled internally here.
sub clearprompt(@)
{
   my $mode = shift;
   my @args = @_;

   local $!;	# don't mess up errno in the caller's world.

   # On Windows we must add an extra level of escaping to any args
   # which might have special chars since all forms of system()
   # appear to go through the %^%@# cmd shell (boo!).
   if (MSWIN) {
      for my $i (0..$#args) {
	 if ($args[$i] =~ /^-(?:pro|ite|def|dfi|dir)/) {
	    $args[$i+1] =~ s/"/'/gs;
	    $args[$i+1] = qq("$args[$i+1]");
	 }
      }
   }

   my $cpt = ccpath('clearprompt');

   # For clearprompt modes in which we get textual data back via a file,
   # derive here a reasonable temp-file name and handle the details
   # of reading the data out of it and unlinking it when done.
   # For other modes, just fire off the cmd and return the status.
   # In a void context, don't wait for the button to be pushed; just
   # "fork" and proceed asynchonously since this is presumably just an
   # informational message.
   # If the cmd took a signal, return undef and leave the signal # in $?.
   if ($mode =~ /text|file|list/) {
      my $outf = tempname($mode);
      my $data;
      if (!system($cpt, $mode, '-out', $outf, @args)) {
	 if (open(OUTFILE, $outf)) {
	    local $/ = undef;
	    $data = <OUTFILE>;
	    $data = '' if !defined $data;
	    close(OUTFILE);
	 }
      } else {
	 # If we took a signal, return undef with the signo in $?. The
	 # clearprompt cmd apparently catches SIGINT and returns 0x400 for
	 # some crazy reason; we fix it here so $? looks like a normal sig2.
	 $? = 2 if $? == 0x400;  # see above
	 $data = undef if $? && $? <= 0x80;
      }
      unlink $outf if -f $outf;
      return $data;
   } else {
      if (defined wantarray) {
	 system($cpt, $mode, @args);
	 $? = 2 if $? == 0x400;  # see above
	 return ($? && $? <= 0x80) ? undef : $?>>8;
      } else {
	 if (MSWIN) {
	    system(1, $cpt, $mode, @args);
	 } else {
	    return if fork;
	    exec($cpt, $mode, @args);
	 }
      }
   }
}

# Fake up a directory chooser using opendir/readdir/closedir and
# 'clearprompt list'.
sub clearprompt_dir {
    my($dir, $msg) = @_;
    my(%subdirs, $items, @drives);
    my $iwd = getcwd;
    $dir = $iwd if $dir eq '.';
    my @pref = $ENV{ATRIA_FORCE_GUI} ? ('-prefer_gui') : ();

    while (1) {
	if (opendir(DIR, $dir)) {
	    %subdirs = map {$_ => 1} grep {-d "$dir/$_" || ! -e "$dir/$_"}
								readdir(DIR);
	    chomp %subdirs;
	    closedir(DIR);
	} else {
	    warn "$dir: $!\n";
	    $dir = File::Spec->rootdir;
	    next;
	}
	if (MSWIN && $dir =~ m%^[A-Z]:[\\/]?$%i) {
	    delete @subdirs{qw(. ..)};
	    @drives = grep {-e} map {"$_:"} 'C'..'Z' if !@drives;
	    $items = join(',', @drives, sort keys %subdirs);
	} else {
	    $items = join(',', sort keys %subdirs);
	}
	my $resp = clearprompt(qw(list -items), $items, @pref,
						    '-pro', "$msg  [ $dir ]");
	if (!defined $resp) {
	    undef $dir;
	    last;
	}
	chomp $resp;
	last if ! $resp || $resp eq '.';
	if (MSWIN && $resp =~ m%^[A-Z]:[\\/]?$%i) {
	    $dir = $resp;
	    chdir $dir || warn "$dir: $!\n";
	} else {
	    $dir = Cwd::abs_path(File::Spec->catdir($dir, $resp));
	}
    }
    chdir $iwd || warn "$iwd: $!\n";
    return $dir;
}

1;
__END__

=head1 NAME

ClearCase::ClearPrompt - Handle clearprompt in a portable, convenient way

=head1 SYNOPSIS

    use ClearCase::ClearPrompt qw(clearprompt clearprompt_dir);

    # boolean usage
    my $rc = clearprompt(qw(yes_no -mask y,n -type ok -prompt), 'Well?');

    # returns text into specified variable (context sensitive).
    my $txt = clearprompt(qw(text -pref -prompt), 'Enter text data here');

    # asynchronous usage - show dialog box and continue
    clearprompt(qw(proceed -mask p -type ok -prompt), "You said: $txt");

    # prompt for a directory (not supported natively by clearprompt cmd)
    my $dir = clearprompt_dir('/tmp', "Please choose a directory");

=head1 DESCRIPTION

Native ClearCase provides a utility (B<clearprompt>) for collecting
user input or displaying messages within triggers. However, usage of
this tool is awkward and error-prone, especially in multi-platform
environments.  Often you must create temp files, invoke clearprompt to
write into them, open them and read the data, then unlink them. In many
cases this code must run seamlessly on both Unix and Windows systems
and is replicated throughout many trigger scripts. ClearCase::ClearPrompt
abstracts this dirty work without changing the interface to
B<clearprompt>.

The C<clearprompt()> function takes the exact same set of flags as
the eponymous ClearCase command, e.g.:

    my $response = clearprompt('text', '-def', '0', '-pro', 'Well? ');

except that the C<-outfile> flag is unnecessary since creation,
reading, and removal of this temp file is managed internally.

In a void context, clearprompt() behaves asynchronously; i.e. it
displays the dialog box and returns so that execution can continue.  In
any other context it waits for the dialog's button to be pushed and
returns the appropriate data type.

The clearprompt() I<function> always leaves the return code of the
clearprompt I<command> in C<$?> just as C<system()> would.  If the
prompt was interrupted via a signal, the function returns the undefined
value.

=head1 DIRECTORY PROMPTING

The clearprompt command has no way to prompt for a directory, so this
module provides a separate C<clearprompt_dir()> function which
implements it via "clearprompt list" and C<opendir/readdir/closedir>.
Usage is

    use ClearCase::ClearPrompt qw(clearprompt_dir);
    $dir = clearprompt_dir($starting_dir, $prompt_string);

This is a little awkward to use since it doesn't use a standard
directory-chooser interface but it works. There's no way to create a
directory within this interface, though.

=head1 NOTE

I<An apparent undocumented "feature" of clearprompt(1) is that it
catches SIGINT (Ctrl-C) and provides a status of 4 rather than
returning the signal number in C<$?> according to normal (UNIX) signal
semantics.>  We fix that up here so it looks like a normal signal 2.
Thus, if C<clearprompt()> returns undef the signal number is reliably
in $? as it should be.

=head1 PORTING

This package is known to work fine on Solaris 2.5.1/perl5.004_04 and
Windows NT 4.0SP3/5.005_02.  As these two platforms are quite
different, this should take care of any I<significant> portability
issues, but please send reports of tweaks needed for other platforms to
the address below.

=head1 AUTHOR

David Boyce <dsb@world.std.com>

Copyright (c) 1999,2000 David Boyce. All rights reserved.  This Perl
program is free software; you may redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

clearprompt(1), perl(1)

=cut
