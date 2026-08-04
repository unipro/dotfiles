;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
(setq user-full-name "Byungwan Jun"
      user-mail-address "unipro.kr@gmail.com")

;; performance tuning
(setq gcmh-high-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 4 1024 1024))  ; for rust-analyzer

;; basic settings
(setq-default window-combination-resize t ; Take new window space from all other windows
              x-stretch-cursor t)         ; Stretch cursor to the glyph width
(setq undo-limit 80000000                 ; Raise undo-limit to 80Mb
      evil-want-fine-undo t               ; By default while in insert all changes are one big blob. Be more granular
      auto-save-default t                 ; Nobody likes to loose work, I certainly don't
      truncate-string-ellipsis "…"        ; Unicode ellispis are nicer than "...", and also save /precious/ space
      password-cache-expiry nil           ; I can trust my computers ... can't I?
      ;; scroll-preserve-screen-position 'always     ; Don't have `point' jump around
      scroll-margin 2                     ; It's nice to maintain a little
      display-time-default-load-average nil)
(display-time-mode 1)                     ; Enable time in the mode-line
(global-subword-mode 1)                   ; Iterate through CamelCase words

;; *scratch* buffer
(setq initial-major-mode 'lisp-interaction-mode) ; Set the initial major mode
(setq initial-scratch-message ";; This buffer is for text that is not saved, and for Lisp evaluation.\n\n")

;; Default frame size
(when window-system
  (add-to-list 'initial-frame-alist '(height . 60))
  (add-to-list 'initial-frame-alist '(width . 160))

  (add-to-list 'default-frame-alist '(height . 60))
  (add-to-list 'default-frame-alist '(width . 160)))

;; Default buffer mode
;; (setq-default major-mode 'org-mode)

(defvar +default-want-RET-continue-comments t
  "If non-nil, RET will continue commented lines.")

(defvar +default-minibuffer-maps
  (append '(minibuffer-local-map
            minibuffer-local-ns-map
            minibuffer-local-completion-map
            minibuffer-local-must-match-map
            minibuffer-local-isearch-map
            read-expression-map)
          (cond ((modulep! :completion ivy)
                 '(ivy-minibuffer-map ivy-switch-buffer-map))
                ((modulep! :completion helm)
                 '(helm-map helm-rg-map helm-read-file-map))))
  "A list of all the keymaps used for the minibuffer.")

;; OS specific fixes
(when (featurep :system 'macos)
  ;; Fix MacOS shift+tab
  (define-key key-translation-map [S-iso-lefttab] [backtab])
  ;; Keybinding settings for macOS
  (setq mac-right-option-modifier 'meta
        ns-right-option-modifier  'meta)
  ;; Fix conventional OS keys in Emacs
  (map! "s-`" #'other-frame  ; fix frame-switching
        ;; fix OS window/frame navigation/manipulation keys
        "s-w" #'delete-window
        "s-W" #'delete-frame
        "s-n" #'+default/new-buffer
        "s-N" #'make-frame
        "s-q" (if (daemonp) #'delete-frame #'save-buffers-kill-terminal)
        "C-s-f" #'toggle-frame-fullscreen
        ;; Restore somewhat common navigation
        "s-l" #'goto-line
        ;; Restore OS undo, save, copy, & paste keys (without cua-mode, because
        ;; it imposes some other functionality and overhead we don't need)
        "s-f" (if (modulep! :completion vertico) #'consult-line #'swiper)
        "s-z" #'undo
        "s-Z" #'redo
        "s-c" (if (featurep 'evil) #'evil-yank #'copy-region-as-kill)
        "s-v" #'yank
        "s-s" #'save-buffer
        "s-x" #'execute-extended-command
        :v "s-x" #'kill-region
        ;; Buffer-local font scaling
        "s-+" #'doom/reset-font-size
        "s-=" #'doom/increase-font-size
        "s--" #'doom/decrease-font-size
        ;; Conventional text-editing keys & motions
        "s-a" #'mark-whole-buffer
        "s-/" (cmd! (save-excursion (comment-line 1)))
        :n "s-/" #'evilnc-comment-or-uncomment-lines
        :v "s-/" #'evilnc-comment-operator
        :gi  [s-backspace] #'doom/backward-kill-to-bol-and-indent
        :gi  [s-left]      #'doom/backward-to-bol-or-indent
        :gi  [s-right]     #'doom/forward-to-last-non-comment-or-eol
        :gi  [M-backspace] #'backward-kill-word
        :gi  [M-left]      #'backward-word
        :gi  [M-right]     #'forward-word))

;; Changing the leader prefixes
;; (setq doom-leader-alt-key "M-m"
;;       doom-localleader-alt-key "M-m m")

;; disable C-z
(global-unset-key (kbd "C-z"))

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
(when (display-graphic-p)
  (cond ((member "JetBrains Mono" (font-family-list))
         (setq doom-font (font-spec :family "JetBrains Mono")))
        ((member "Droid Sans Mono" (font-family-list))
         (setq doom-font (font-spec :family "Droid Sans Mono")))
        ((member "DejaVu Sans Mono" (font-family-list))
         (setq doom-font (font-spec :family "DejaVu Sans Mono")))
        (t
         (message "'JetBrains Mono', 'Droid Sans Mono' or 'DejaVu Sans Mono' are not installed")))
  (cond ((member "D2Coding" (font-family-list))
         (setq doom-symbol-font (font-spec :family "D2Coding")))
        ((member "NanumGothicCoding" (font-family-list))
         (setq doom-symbol-font (font-spec :family "NanumGothicCoding")))
        (t
         (message "'D2Coding' or 'NanumGothicCoding' are not installed")))
  ;; font size
  (cond ((featurep :system 'macos)
         (set-face-attribute 'default nil :height 150 :weight 'semi-light))
        ((featurep :system 'windows)
         (set-face-attribute 'default nil :height 120 :weight 'semi-light))
        (t
         (set-face-attribute 'default nil :height 140 :weight 'semi-light))))

;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(if (display-graphic-p)
    (setq doom-theme 'doom-solarized-light)
  (setq doom-theme nil))

;; In Emacs 28 you can tell Emacs to jump to the first or last match in the buffer,
;; with M-< and M->; or the next or previous match not currently visible
;; with C-v and M-v.
(when (>= emacs-major-version 28)
  (setq isearch-allow-motion t))

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type nil)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; coding-system
(require 'ucs-normalize)
(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-buffer-file-coding-system 'utf-8)
(setq-default coding-system-for-write 'utf-8)
(cond ((featurep :system 'windows)
       (setq-default coding-system-for-read 'utf-8) ; XXX 'utf-16-le
       (set-clipboard-coding-system 'utf-16-le)
       (set-selection-coding-system 'utf-16-le))
      ((featurep :system 'macos)
       (setq-default coding-system-for-read 'utf-8-hfs)
       (set-clipboard-coding-system 'utf-8-hfs)
       (set-selection-coding-system 'utf-8-hfs)
       (set-file-name-coding-system 'utf-8-hfs)
       (setq default-process-coding-system '(utf-8-hfs . utf-8-hfs)))
      (t  ; linux
       (setq-default coding-system-for-read 'utf-8)
       (setq x-select-request-type
             '(UTF8_STRING COMPOUND_TEXT TEXT STRING))))

;; Enable korean input
(setq default-input-method "korean-hangul")
(global-set-key (kbd "S-SPC") 'toggle-input-method)

;; avy
(setq avy-all-windows nil
      avy-all-windows-alt t
      avy-background t
      ;; the unpredictability of this (when enabled) makes it a poor default
      avy-single-candidate-jump nil)
(global-set-key (kbd "M-g c") 'avy-goto-char)
(global-set-key (kbd "M-g C") 'avy-goto-char-2)
(global-set-key (kbd "M-g l") 'avy-goto-line)
(global-set-key (kbd "M-g w") 'avy-goto-word-1)

;; Hippie expand
(global-set-key [remap dabbrev-expand] #'hippie-expand)
(setq hippie-expand-try-functions-list
      '(try-expand-list
        try-expand-dabbrev-visible
        try-expand-dabbrev
        try-expand-all-abbrevs
        try-expand-dabbrev-all-buffers
        try-complete-file-name-partially
        try-complete-file-name
        try-expand-dabbrev-from-kill
        try-expand-whole-kill
        try-expand-line
        try-complete-lisp-symbol-partially
        try-complete-lisp-symbol))

;; smartparens
(use-package! smartparens)

;; like paredit keybinding
(map!
  :after smartparens
  :map smartparens-mode-map
  "M-(" #'sp-wrap-round
  "M-s" #'sp-splice-sexp
  "C-)" #'sp-forward-slurp-sexp
  "C-}" #'sp-forward-barf-sexp
  "C-(" #'sp-backward-slurp-sexp
  "C-{" #'sp-backward-barf-sexp)

;; man
(after! woman
  ;; The woman-manpath default value does not necessarily match man. If we have
  ;; man available but aren't using it for performance reasons, we can extract
  ;; it's manpath.
  (when (executable-find "man")
    (setq woman-manpath
          (split-string (cdr (doom-call-process "man" "--path"))
                        path-separator t))))

;; treemacs
(use-package! treemacs
  :bind
  (:map global-map
    ("M-o" . treemacs-select-window))
  :config
  (treemacs-load-theme "Default")
  (add-to-list 'treemacs-pre-file-insert-predicates #'treemacs-is-file-git-ignored?))

(after! (treemacs projectile)
  (treemacs-project-follow-mode 1))

;; tree-sitter
;; Major-mode remapping and grammar recipes come from `:tools tree-sitter' plus
;; the per-language `+tree-sitter' flags in init.el -- don't duplicate them here.
;; A manual `major-mode-remap-alist' outranks Doom's `major-mode-remap-defaults'
;; and loses grammar auto-install, mode-hook inheritance, and the
;; missing-grammar fallback. Use `set-tree-sitter!' for languages Doom misses.
;; Only override the indent offsets whose upstream default isn't 4.
(setq-default c-ts-mode-indent-offset 4    ; default 2; covers c++-ts-mode too
              go-ts-mode-indent-offset 4)  ; default 8

;; exec-path-from-shell
(use-package! exec-path-from-shell
  :when (memq window-system '(mac ns))
  :config
  (setq exec-path-from-shell-arguments '("-l" "-i")) ; Login + Interactive shell
  (exec-path-from-shell-initialize))

;; Resolve system build error in macOS Emacs when CC is set to gcc-xx
(when (featurep :system 'macos)
  (when (file-executable-p "/opt/homebrew/opt/llvm/bin/clang")
    (setenv "CC" "/opt/homebrew/opt/llvm/bin/clang")
    (setenv "CXX" "/opt/homebrew/opt/llvm/bin/clang++")))

;; (after! compile
;;   (add-to-list 'compilation-error-regexp-alist-alist
;;                '(rust-test-panic
;;                  "^thread '.*' .*panicked at \\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\):$"
;;                  1 2 3))
;;   (add-to-list 'compilation-error-regexp-alist-alist
;;                '(rust-test-panic
;;                  "^thread '.*' .*panicked at \\([^:\n]+\\):\\([0-9]+\\):\\([0-9]+\\):$"
;;                  1 2 3))
;;   (add-to-list 'compilation-error-regexp-alist 'rust-test-panic)
;;   (add-to-list 'compilation-error-regexp-alist 'rust-test-panic-generic))

;; lisp
(add-hook! '(emacs-lisp-mode-hook lisp-mode-hook common-lisp-mode-hook)
  (setq-local lisp-indent-offset 2))

;; python
(after! python
  (setq python-shell-interpreter "python3"
        flycheck-python-pycompile-executable "python3"
        doom-modeline-env-python-executable "python3"))

(after! projectile
  (projectile-register-project-type 'python-poetry '("poetry.lock")
                                    :project-file "poetry.lock"
                                    :compile "poetry build"
                                    :test "poetry run pytest"
                                    :test-prefix "test_"
                                    :test-suffix "_test"))

;; unset the backends for a sh mode
(after! sh-script
  (set-company-backend! 'sh-mode nil))

;; eglot
(after! eglot
  (setq-default eglot-inlay-hints-mode nil)
  (add-hook 'eglot-managed-mode-hook (lambda () (eglot-inlay-hints-mode -1))))

;; dotenv-mode
(add-to-list 'auto-mode-alist '("\\.env\\..*\\'" . dotenv-mode))

;; fix the error caused by proselint craching on macOS
(when (featurep :system 'macos)
  (after! flycheck
    (setq-default flycheck-disabled-checkers '(proselint))))

;; gptel
(use-package! gptel
  :config
  ;; TODO
  )

;; copilot-chat
;; (use-package! copilot-chat
;;   :bind (:map global-map
;;          ("C-c C-y" . copilot-chat-yank)
;;          ("C-c M-y" . copilot-chat-yank-pop)
;;          ("C-c C-M-y" . (lambda () (interactive) (copilot-chat-yank-pop -1))))
;;   :init
;;   (add-hook 'git-commit-setup-hook 'copilot-chat-insert-commit-message))

;; copilot
;; accept completion from copilot and fallback to company
;; (use-package! copilot
;;   ;; :hook (prog-mode . copilot-mode)
;;   :bind (:map copilot-completion-map
;;           ("<tab>" . 'copilot-accept-completion)
;;           ("TAB" . 'copilot-accept-completion)
;;           ("C-TAB" . 'copilot-accept-completion-by-word)
;;           ("C-<tab>" . 'copilot-accept-completion-by-word)
;;           ("C-n" . 'copilot-next-completion)
;;           ("C-p" . 'copilot-previous-completion)))

;; org-ai
(use-package! org-ai
  :hook (org-mode . org-ai-mode)
  :config
  ;; TODO
  )

;; claude-code
(use-package! claude-code-ide
  :commands (claude-code-ide claude-code-ide-menu)
  :config
  (claude-code-ide-emacs-tools-setup))

;; mcp
(use-package! mcp
  :after gptel)

(map! :leader
  (:prefix-map ("'" . "AI")
    ;; claude-code-ide
    :desc "Claude Code"             "c" #'claude-code-ide
    :desc "Menu (Claude Code)"      "m" #'claude-code-ide-menu
    :desc "Quit Claude Code"        "q" #'claude-code-ide-quit
    :desc "Switch to Claude buffer" "b" #'claude-code-ide-switch-to-buffer
    :desc "Send prompt"             "p" #'claude-code-ide-send-prompt
    :desc "Toggle Claude Code"      "t" #'claude-code-ide-toggle
    ;; gptel
    ;; :desc "Chat (gptel)"            "a" #'gptel
    ;; :desc "Menu (switch backend)"   "m" #'gptel-menu
    ;; :desc "Inline rewrite"          "r" #'gptel-rewrite
    ;; copilot
    ;; :desc "Copilot"                "C" #'copilot-mode
    ))

;; Show the modeline in vterm buffer
(remove-hook 'vterm-mode-hook  #'hide-mode-line-mode)
(after! vterm
  (set-popup-rule! "^\\*vterm" :size 0.25 :vslot -4 :select t :quit nil :ttl 0 :modeline t))

;; auto-customisations
(setq-default custom-file (expand-file-name "custom.el" doom-user-dir))
(when (file-exists-p custom-file)
  (load custom-file))

;; local-customisations
(setq-default local-file (expand-file-name "local.el" doom-user-dir))
(when (file-exists-p local-file)
  (load local-file))

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
