use strict;
use warnings;
use ExtUtils::MakeMaker;
use Object::Pad::ExtensionBuilder;
use XS::Parse::Keyword::Builder;

# Both builders only contribute `-I<sharedir>/include` flags via
# extra_compiler_flags. Capture them once at `perl Makefile.PL` time and
# feed them to EUMM through INC.
my $inc = join ' ',
    Object::Pad::ExtensionBuilder->extra_compiler_flags,
    XS::Parse::Keyword::Builder->extra_compiler_flags;

WriteMakefile(
    DISTNAME         => 'Object-PadX-Enum',
    NAME             => 'Object::PadX::Enum',
    VERSION_FROM     => 'lib/Object/PadX/Enum.pm',
    ABSTRACT         => 'syntactic sugar for enum-like singleton-bearing Object::Pad classes',
    AUTHOR           => 'Davenonymous <perl@davenonymous.com>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.022',

    XSMULTI => 1,
    INC     => $inc,

    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'           => '7.12',
        'Object::Pad::ExtensionBuilder' => '0',
        'XS::Parse::Keyword::Builder'   => '0.48',
    },
    BUILD_REQUIRES => {
        'Object::Pad::ExtensionBuilder' => '0',
        'XS::Parse::Keyword::Builder'   => '0.48',
    },
    PREREQ_PM => {
        'Object::Pad'        => '0.825',
        'XS::Parse::Keyword' => '0.48',
        'XSLoader'           => '0',
    },
    TEST_REQUIRES => {
        'Test2::V0' => '0',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            homepage   => 'https://github.com/davenonymous/perl-object-padx-enum',
            bugtracker => { web => 'https://github.com/davenonymous/perl-object-padx-enum/issues' },
            repository => {
                type => 'git',
                url  => 'https://github.com/davenonymous/perl-object-padx-enum.git',
                web  => 'https://github.com/davenonymous/perl-object-padx-enum',
            },
        },
        dynamic_config => 1,
    },
);

sub MY::postamble {
    return <<'MAKE_FRAG';

# --- README regeneration ---------------------------------------------
# Usage: make readme
#
# README.md is the GitHub-facing rendering of the pod in Enum.pm; it is
# not shipped in the dist (see MANIFEST.SKIP), so distcheck cannot flag
# drift. Regenerate it after any pod change.

.PHONY: readme

readme :
	@command -v pod2markdown >/dev/null 2>&1 || { \
	    echo "ERROR: pod2markdown not found in PATH; cpanm Pod::Markdown"; \
	    exit 1; \
	}
	pod2markdown lib/Object/PadX/Enum.pm > README.md

# --- Release target -------------------------------------------------
# Usage: make release
#
# Tests the dist via `make disttest`, builds the tarball via
# `make dist` (disttest alone only creates the unpacked directory),
# then uploads it to CPAN with cpan-upload (from CPAN::Uploader).
# Refuses to run if the git working tree is dirty, if a tag for the
# current $(VERSION) already exists, or if the GitHub CI run of HEAD
# has not passed (ci-check, which needs gh). See RELEASING.md.
#
# disttest and dist run as separate sub-makes on purpose: as
# prerequisites of one target they would share a single distdir
# build, and the tarball would pack the blib/ that disttest left
# behind. PAUSE refuses to index such a tarball.

.PHONY: release release-check ci-check

ci-check :
	@command -v gh >/dev/null 2>&1 || { \
	    echo "ERROR: gh not found in PATH; it reads the CI result of the release commit."; \
	    exit 1; \
	}
	@commit=$$(git rev-parse HEAD) || exit 1; \
	run=$$(gh run list --workflow ci.yml --commit "$$commit" --limit 1 --json status,conclusion --jq '.[] | "\(.status) \(.conclusion)"') || exit 1; \
	case "$$run" in \
	    "completed success") ;; \
	    "") echo "ERROR: no CI run for $$commit; push it and wait for CI first."; exit 1 ;; \
	    "completed "*) echo "ERROR: the CI run for $$commit did not pass ($${run#completed }); see gh run list --commit $$commit."; exit 1 ;; \
	    *) echo "ERROR: the CI run for $$commit has not finished; wait with gh run watch."; exit 1 ;; \
	esac

release-check : ci-check
	@git diff-index --quiet HEAD -- || { \
	    echo "ERROR: git working tree is dirty; commit or stash first."; \
	    exit 1; \
	}
	@if git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null; then \
	    echo "ERROR: tag v$(VERSION) already exists; bump \$$VERSION in lib/Object/PadX/Enum.pm."; \
	    exit 1; \
	fi
	@command -v cpan-upload >/dev/null 2>&1 || { \
	    echo "ERROR: cpan-upload not found in PATH; cpanm CPAN::Uploader"; \
	    exit 1; \
	}
	@test -r $(HOME)/.pause || { \
	    echo "ERROR: ~/.pause not found; see RELEASING.md for the format."; \
	    exit 1; \
	}

release :: release-check
	$(MAKE) disttest
	$(MAKE) dist
	@test -f $(DISTVNAME).tar.gz || { \
	    echo "ERROR: $(DISTVNAME).tar.gz was not built; refusing to upload."; \
	    exit 1; \
	}
	@if tar tzf $(DISTVNAME).tar.gz | grep -qE '/(blib/|Makefile$$|MYMETA\.|pm_to_blib|Enum\.c$$|[^/]*\.(o|so|bs)$$)'; then \
	    echo "ERROR: $(DISTVNAME).tar.gz contains build artefacts; refusing to upload."; \
	    exit 1; \
	fi
	cpan-upload $(DISTVNAME).tar.gz
	@echo
	@echo "Uploaded $(DISTVNAME).tar.gz to PAUSE."
	@echo "Next:"
	@echo "  git tag -a v$(VERSION) -m 'Release v$(VERSION)'"
	@echo "  git push --follow-tags"
MAKE_FRAG
}
