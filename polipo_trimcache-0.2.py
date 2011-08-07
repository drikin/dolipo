#!/usr/bin/env python
# -*- Mode: Python; tab-width: 8; py-indent-offset: 8; indent-tabs-mode: nil -*-
# 
# polipo_trimcache version 0.2
# Written by J.P. Larocque, <piranha@thoughtcrime.us>, OpenPGP 0xF61D2E61
# This software is in the public domain.
# 
# Polipo is a small, caching HTTP proxy with nifty features like
# client and server IPv6 support, pipelining, and the caching of
# partial objects.  See: http://www.pps.jussieu.fr/~jch/software/polipo/
# 
# Polipo doesn't have any built-in facility for keeping its cache
# directory under a given fixed size.  This script implements that: it
# trims your cache directory to a target size by removing the files with
# oldest access times until the cache size is smaller than or equal to
# the target size.
# 
# This script requires Python 2.2 or greater.
# 
# Some notes about polipo_trimcache's operation:
#     * Send Polipo SIGUSR1 prior to and SIGUSR2 after running this
#       script, as if you were using Polipo's own cache-purging
#       facility.  This is explained in the manual:
#       http://www.pps.jussieu.fr/~jch/software/polipo/manual/Purging.html
#     * If you run Polipo non-root (as you should), you should also run
#       this script as the same user.  It is conceivable that, given a
#       carefully-crafted cache directory, polipo_trimcache could mangle
#       with things outside the cache, either because of bugs in the
#       script or in Python.  Restricting this script to execution by
#       the same or another isolated user will protect you from problems
#       a cracker could cause if Polipo were cracked.  (No current
#       security issues with any of these pieces of software are known
#       by the author at the time of writing.)
#     * Hidden files and files other than regular files and directories
#       are skipped.  This means symlinks are not honored, with the
#       exception of the root cache directory.  This shouldn't matter
#       for normal use.
#     * On systems that report it, polipo_trimcache uses st_blocks
#       from stat().  If st_blocks is 0 for a given file/directory, it
#       uses st_size instead.
#     * polipo_trimcache removes directories when it removes the last
#       file from them (except for the root cache directory).
#
# Bugs: (both of which are caused by the last point above)
#     * Empty directories aren't removed if they didn't contain any
#       files to begin with.
#     * Dry-run mode never pretends to remove directories, since it
#       never removes files, enabling the condition for directories to
#       be removed.
# 
# The latest version of this program can be found at the URL:
#       http://ely.ath.cx/~piranha/software/polipo_trimcache/
# This program has been signed with my public key.  Its fingerprint is:
#       5612 10A8 4986 2D85 A995  252B 4C02 5E02 F61D 2E61
# The detached signature can be found at the URL:
#       http://ely.ath.cx/~piranha/software/polipo_trimcache/polipo_trimcache-0.2.py.asc
# 
# Changelog:
#   version 0.2 (2004/Aug/10)
#       Cleaned up for initial release.
#   version 0.1 (2004/Jun/27)
#       Initially written.
# 

help = \
"""Usage: polipo_trimcache [-fnpvVDh?] POLIPO_CACHE_DIR TARGET_SIZE
	-f, --force
		Force questionable behavior.  Currently this means
		continuing even when the TARGET_SIZE is less than 2KB.
	-n, --no-op, --dry-run
		Don't make any changes to the cache contents.  Print
		the files that would be deleted instead.
	-p, --precise-expiry
		Determines last-access time of cache files by opening
		them and reading their X-Polipo-Access header.  The
		default behavior is to use the last-modification time
		of the file, which should be faster.  Analogous to the
                Polipo configuration option "preciseExpiry".
	-v, --verbose
		Verbose operation.  Prints every stage of the operation,
                and reports hidden or special files.
	-V, --version
        	Print version number, and exit.
	-D, --debug
        	Debugging mode.  Report each directory on cache
                transversal, and each unlink/rmdir operation.
	-h, -?, --help
        	Print usage information.

POLIPO_CACHE_DIR specifies the root of the Polipo cache.  TARGET_SIZE
specifies the size polipo_trimcache trims down to, expressed in bytes.
(You may specify megabytes or gigabytes by appending "M" or "G" to the
size argument.  The quantifiers [KMGTPEZY] are supported (future-
proof!).)

Example:
	polipo_trimcache /var/local/cache/polipo 256M
Keeps said cache directory under 256 megabytes.
"""

version = "0.2"
last_modified = "2004/August/10"

import os, os.path, sys, re, stat, time, getopt, math, rfc822
me = os.path.basename (sys.argv[0])

# These are defaults, not hard-coded settings.
force_mode = 0
no_op_mode = 0
precise_expiry_mode = 0
verbose_mode = 0
debug_mode = 0

def main (args):
        global force_mode, no_op_mode, precise_expiry_mode, verbose_mode, debug_mode
        
	try:
		options, extra = getopt.getopt (args, "fnpvVDh?", ("force", "no-op", "noop", "dry-run", "precise-expiry",
				                                   "verbose", "help", "version", "debug"))
	except getopt.GetoptError, msg:
		usage ()
		return 1

	for option, argument in options:
		if option in ("-f", "--force"):
			force_mode = 1
		elif option in ("-n", "--no-op", "--noop", "--dry-run"):
			no_op_mode = 1
		elif option in ("-p", "--precise-expiry"):
			precise_expiry_mode = 1
		elif option in ("-v", "--verbose"):
			verbose_mode = 1
		elif option in ("-h", "-?", "--help"):
			sys.stdout.write (help)
                        return 0
		elif option in ("-V", "--version"):
			print "%s version %s (%s)" % (me, version, last_modified)
			return 0
		elif option in ("-D", "--debug"):
			debug_mode = 1

	if len (extra) != 2:
		usage ()
		return 1
	cache_dir = extra[0]
	target_size = hr2num (extra[1])

        verbose_msg ("Transversing cache...")
	cobjs, cdirs = transverse_cache (cache_dir)
        
        verbose_msg ("Sorting and counting...")
        cobjs.sort (lambda o1, o2: cmp (o2.last_access, o1.last_access))
        total_size = 0L
        for cfile in cobjs + cdirs:
                total_size += cfile.size
        verbose_msg ("Cache is currently %sB (%d files, %d dirs)." % (num2hr (total_size), len (cobjs), len (cdirs)))
        
        verbose_msg ("Trimming...")
        files_removed = dirs_removed = 0
        latest_trimmed = None
        while cobjs and (total_size > target_size):
                # Delete the oldest-used cache object, and possibly its parent directory.
                victim = cobjs.pop ()
                if no_op_mode:
                        print victim.path
                else:
                        debug_msg ("Removing file: %s" % victim.path)
                        os.unlink (victim.path)
                total_size -= victim.size
                files_removed += 1
                latest_trimmed = victim.last_access

                # Now delete parent and grandparent directories, if empty.
                victim = victim.parent
                while victim:
                        victim.children -= 1
                        # We add the check for files with listdir in case there's any files we skipped over (hidden, special).
                        if (victim.children == 0) and (not os.listdir (victim.path)):
                                if no_op_mode:
                                        debug_msg ("Removing directory [NOOP]: %s" % victim.path)
                                else:
                                        debug_msg ("Removing directory: %s" % victim.path)
                                        os.rmdir (victim.path)
                                total_size -= victim.size
                                cdirs.remove (victim)
                                dirs_removed += 1

                                # Parent directory is now the next candidate for removal.
                                victim = victim.parent
                        else:
                                break
        
        verbose_msg ("Cache trimmed (-%d files, -%d dirs) to %sB (%d files, %d dirs)." % \
                    (files_removed, dirs_removed, num2hr (total_size), len (cobjs), len (cdirs)))
        if latest_trimmed is not None:
                verbose_msg ("Latest file removed was %s old" % secs2thr (int (time.time ()) - latest_trimmed))

def warn (msg):
	sys.stderr.write ("%s: %s\n" % (me, msg))

def usage ():
	warn ("usage: %s [-fnpvVDh?] POLIPO_CACHE_DIR TARGET_SIZE" % me)

def verbose_msg (msg):
	if verbose_mode: warn (msg)

def debug_msg (msg):
	if debug_mode: warn (msg)


class CacheFile:
        """Superclass for any kind of (non-special) file found in the Polipo cache tree."""
        pass

class CacheDir (CacheFile):
        """Class for directories only."""
        
	def __init__ (self, parent = None):
		self.parent = parent
                self.children = None
                self.size = None
                self.path = None
        
        def __repr__ (self):
                # Still waiting on that ternary operator.  OH WAIT, those "decrease readability".
                if self.children is None: children = "?"
                else: children = str (self.children)
                
                if self.size is None: size = "?"
                else: size = str (self.size)

                if self.path is None: path = "?"
                else: path = "\"%s\"" % self.path
                
                return "<CacheDir instance, path=%s, children=%s, size=%s, has_parent=%d>" % \
                       (path, children, size, self.parent != None)

class CacheObject (CacheFile):
        """Class for regular files (cached HTTP objects) only."""
        
	def __init__ (self, parent = None):
		self.parent = parent
                self.last_access = None
                self.size = None
                self.path = None
        
        def __repr__ (self):
                if self.last_access is None: last_access = "?"
                else: last_access = time.strftime ("[%Y/%m/%d %H:%M:%S]", time.localtime (self.last_access))
                
                if self.size is None: size = "?"
                else: size = str (self.size)

                if self.path is None: path = "?"
                else: path = "\"%s\"" % self.path
                
                return "<CacheObject instance, path=%s, last_access=%s, size=%s, has_parent=%d>" % \
                       (path, last_access, size, self.parent != None)

def transverse_cache (dir, parent = None):
	"""Recursively transverses a given directory.  Returns a tuple of 0) a list of all found files as CacheObject instances, and 1) a list of all found directories as CacheDir instances (except for the given root directory).  Note that the return values are flat lists and not some sort of tree structure.  If parent is given, each file in the given directory will be assigned its value as the parent directory, and the children attribute of the parent will be assigned the number of children found in the given directory."""

	debug_msg ("Entering directory: %s" % dir)
	cobjs = []
        cdirs = []

	children = 0
	for file in os.listdir (dir):
		file_full = os.path.join (dir, file)
		if file.startswith ("."):
			verbose_msg ("Skipping hidden file: %s" % file_full)
			continue
		
		file_stat = os.lstat (file_full)
		if stat.S_ISDIR (file_stat.st_mode):
                        cfile = CacheDir (parent)
                        cdirs.append (cfile)
                        sub_cobjs, sub_cdirs = transverse_cache (file_full, cfile)
                        cobjs += sub_cobjs
                        cdirs += sub_cdirs
                        del (sub_cobjs, sub_cdirs)
		elif stat.S_ISREG (file_stat.st_mode):
                        cfile = CacheObject (parent)
                        cobjs.append (cfile)
			if precise_expiry_mode:
				cfile.last_access = get_precise_access (file_full)
                                # If there is no precise access-time information, we use something "very old":
                                if cfile.last_access == None:
                                        cfile.last_access = 0
			else:
				cfile.last_access = file_stat.st_mtime
		else:
			verbose_msg ("Skipping special file: %s" % file_full)
			continue
                
                try:
                        cfile.size = file_stat.st_blocks * 512
                        # Directories seem to have an st_blocks value of 0.
                        if cfile.size == 0:
                                cfile.size = file_stat.st_size
                except AttributeError:
                        cfile.size = file_stat.st_size
                
                cfile.path = file_full
                children += 1
        
        if parent:
                parent.children = children
	return cobjs, cdirs

def get_precise_access (file_name):
	"""Open a Polipo cache file and return its last access time, determined from X-Polipo-Access."""

	access = None
	file = open (file_name)
        # For HTTP header line:
        file.readline ()
        line_num = 1
	while 1:
                line_num += 1
                line = file.readline ()
		if line == "\r\n": break
                try:
                        header, value = line.split (": ", 1)
                        if header.lower () == "x-polipo-access":
                                access = int (rfc822.mktime_tz (rfc822.parsedate_tz (value)))
                except ValueError:
                        whine ("Reading \"%s\":%d" % (file_name, line_num))
                        break
	file.close ()

	return access

def whine (msg):
        """Warns the given message and information on the current exception being handled."""
        exc_class, exc_instance = sys.exc_info ()[:2]
        exc_args = exc_instance.args
        warn ("%s: %s: %s" % (msg, exc_class, exc_args))                

hr2num_re = re.compile (r'^([0-9]+(?:\.[0-9]+)?) *([KMGTPEZY]?)$', re.I)
quants_dict = {
        'K': 1024L ** 1,
        'M': 1024L ** 2,
        'G': 1024L ** 3,
        'T': 1024L ** 4,
        
        # It's uh, future-proof...
        'P': 1024L ** 5,
        'E': 1024L ** 6,
        'Z': 1024L ** 7,
        'Y': 1024L ** 8,
        }
quants_tups = quants_dict.items ()
quants_tups.sort (lambda t1, t2: cmp (t1[1], t2[1]))
quants_tups_dec = quants_tups
quants_tups_dec.reverse ()

tquants_dict = {
        'm': 60,
        'h': 60 * 60,
        'd': 60 * 60 * 24,
        'w': 60 * 60 * 24 * 7,
        }
tquants_tups = tquants_dict.items ()
tquants_tups.sort (lambda t1, t2: cmp (t1[1], t2[1]))
tquants_tups_dec = tquants_tups
tquants_tups_dec.reverse ()

def hr2num (hr):
	"""Given a string with an integral or floating-pointing number and an optional quantifier, return a long of the expressed amount."""

	match = hr2num_re.match (hr)
	if match:
		amount = float (match.group (1))
		quant = match.group (2)
		if quant:
			amount *= quants_dict[quant.upper ()]
		return long (math.ceil (amount))
	else:
		raise ValueError, "bad human-readable expression (\"NN.N[KMGTPEZY]\")"

def num2hr (num):
        """Given an integer, return a string with the same amount expressed with a quantifier."""

        num = long (num)
        for quant_abbr, quant_amount in quants_tups_dec:
                if num >= quant_amount:
                        return "%.2f%s" % (float (num) / quant_amount, quant_abbr)
	
	return str (num)

def secs2thr (seconds):
        output = ""
        for quant_abbr, quant_amount in tquants_tups_dec:
                if seconds >= quant_amount:
                        q_amount = int (seconds) / quant_amount
                        seconds -= q_amount * quant_amount
                        output += "%d%s" % (q_amount, quant_abbr)

        if seconds == math.floor (seconds):
                output += "%ds" % seconds
        else:
                output += "%.1fs" % seconds
        
        return output


if __name__ == "__main__":
	sys.exit (main (sys.argv[1:]))
