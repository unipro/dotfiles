;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; To install a package with Doom you must declare them here and run 'doom sync'
;; on the command line, then restart Emacs for the changes to take effect -- or
;; use 'M-x doom/reload'.

;; exec-path-from-shell
(package! exec-path-from-shell)

;; dotenv
(package! dotenv-mode)

;; Hard dependency of claude-code-ide's MCP tools server
;; (claude-code-ide-mcp-http-server.el requires it at runtime, and
;; `claude-code-ide-mcp-server' errors out without it). Declared
;; explicitly rather than leaning on straight's transitive resolution.
(package! web-server)

;; Claude Code IDE (runs inside a ghostel terminal, see config.el)
;; (package! claude-code
;;   :recipe (:host github :repo "stevemolitor/claude-code.el"))
(package! claude-code-ide
  :recipe (:host github :repo "manzaltu/claude-code-ide.el"))

;; Terminal backend for claude-code-ide. Ghostel drives libghostty-vt (the
;; VT engine behind Ghostty) through a native module, so it avoids the
;; flicker and reflow artifacts vterm and eat show while Claude redraws its
;; TUI. The module is a pre-built binary fetched from GitHub releases on
;; first use -- no zig toolchain needed, but the first `M-x ghostel' (or
;; first Claude session) asks before downloading it.
(package! ghostel)

;; To install SOME-PACKAGE from MELPA, ELPA or emacsmirror:
;; (package! some-package)

;; To install a package directly from a remote git repo, you must specify a
;; `:recipe'. You'll find documentation on what `:recipe' accepts here:
;; https://github.com/radian-software/straight.el#the-recipe-format
;; (package! another-package
;;   :recipe (:host github :repo "username/repo"))

;; If the package you are trying to install does not contain a PACKAGENAME.el
;; file, or is located in a subdirectory of the repo, you'll need to specify
;; `:files' in the `:recipe':
;; (package! this-package
;;   :recipe (:host github :repo "username/repo"
;;            :files ("some-file.el" "src/lisp/*.el")))

;; If you'd like to disable a package included with Doom, you can do so here
;; with the `:disable' property:
;; (package! builtin-package :disable t)

;; You can override the recipe of a built in package without having to specify
;; all the properties for `:recipe'. These will inherit the rest of its recipe
;; from Doom or MELPA/ELPA/Emacsmirror:
;; (package! builtin-package :recipe (:nonrecursive t))
;; (package! builtin-package-2 :recipe (:repo "myfork/package"))

;; Specify a `:branch' to install a package from a particular branch or tag.
;; This is required for some packages whose default branch isn't 'master' (which
;; our package manager can't deal with; see radian-software/straight.el#279)
;; (package! builtin-package :recipe (:branch "develop"))

;; Use `:pin' to specify a particular commit to install.
;; (package! builtin-package :pin "1a2b3c4d5e")


;; Doom's packages are pinned to a specific commit and updated from release to
;; release. The `unpin!' macro allows you to unpin single packages...
;; (unpin! pinned-package)
;; ...or multiple packages
;; (unpin! pinned-package another-pinned-package)
;; ...Or *all* packages (NOT RECOMMENDED; will likely break things)
;; (unpin! t)
