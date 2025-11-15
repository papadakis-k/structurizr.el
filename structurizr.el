;;; structurizr.el --- Major mode for Structurizr DSL  -*- lexical-binding: t; -*-

;; Copyright (C) 2025  Kostas Papadakis

;; Author: Kostas Papadakis
;; Maintainer: Kostas Papadakis
;; Version: 1.0
;; Package-Requires: ((emacs "29.1"))
;; Homepage: https://github.com/papadakis-k/structurizr.el
;; Keywords: languages

;; This file is NOT part of GNU Emacs

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This is a major mode for editing Structurizr DSL files. It is based
;; on Structurizr treesitter for font-locking and identation.
;; Additionally it registers within `eglot-server-programs' so we can
;; also use Eglot.

;;; Code:

(require 'treesit)
(require 'eglot)

(defvar structurizr--font-lock-settings
  (treesit-font-lock-rules
   :default-language 'structurizr

   :feature 'comments
   :override t
   '((comment) @font-lock-comment-face)

   :feature 'strings
   :override t
   '((string) @font-lock-string-face)

   :feature 'variables
   '((variable_declaration name: (identifier) @font-lock-variable-name-face))

   :feature 'relations
   '((relation_statement (_) @font-lock-function-call-face))

   :feature 'colors
   '((color) @structurizr--colorize-color)

   :feature 'errors
   '((ERROR) @font-lock-warning-face))
  "Font lock settings for Structurizr.")

(defvar structurizr--indent-rules
  `((structurizr
     ((node-is "workspace_declaration") column-0 0)
     ((node-is "}") parent-bol 0)
     ((parent-is "_declaration") parent-bol tab-width)
     (catch-all parent-bol 0))))

(defun structurizr--colorize-color(node _ _ _ &rest _)
  "Colorize the treesitter NODE with its CSS color."
  (let* ((start (treesit-node-start node))
         (end (treesit-node-end node))
         (bg-color (treesit-node-text node))
         (light (caddr (apply 'color-rgb-to-hsl (color-name-to-rgb bg-color))))
         (fg-color (if (> light 0.5) "#000" "#fff")))
    (put-text-property start end 'face
                       `(:background ,bg-color :foreground ,fg-color))))

;; Register the tree-sitter repository for Structurizr
(setf (alist-get 'structurizr treesit-language-source-alist)
      '("https://github.com/josteink/tree-sitter-structurizr"
        :commit "7a29c74bd18b763d86c919d74a2f730e3c341666"))

(defcustom structurizr-language-server-path
  "~/programs/c4-language-server/bin/c4-language-server"
  "Path of the executable of the Structurizr Language Server.

This is just the path, the arguments are handled separately cause we
really need network mode for this language server (\"-c socket\")."
  :group 'structurizr
  :type '(string))

(defun structurizr--eglot-connect(_ _)
  "Helper function for wiring up Eglot to this LS."
  (let ((buffer-name "*EGLOT c4-language-server process*")
        (src-dir (file-name-directory (symbol-file 'structurizr-mode))))
    (ignore-errors
      (async-shell-command
       (format "JAVA_TOOL_OPTIONS=-Dlogback.configurationFile=%s/logback.xml \
%s -c socket" src-dir structurizr-language-server-path) buffer-name))
    (sit-for 1))
  '("localhost" 5008))

(setf (alist-get 'structurizr-mode eglot-server-programs)
      'structurizr--eglot-connect)

;;; Major mode definition
(define-derived-mode structurizr-mode prog-mode "Structurizr"
  "Major mode for editing Structurizr DSL."
  :group 'structurizr

  (if (not (treesit-ready-p 'structurizr))
      (treesit-ensure-installed 'structurizr))

  (if (not (treesit-ready-p 'structurizr))
      (error "This mode needs tree-sitter support! You can install it with M-x treesit-install-language-grammar"))
  
  (setq treesit-primary-parser (treesit-parser-create 'structurizr))
  (setq-local treesit-font-lock-settings structurizr--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comments strings)
                (variables)
                (errors colors)
                (relations)))

  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip (rx "//" (* (syntax whitespace))))

  (setq-local electric-indent-chars '(?\C-j ?}))

  (setq-local treesit-simple-indent-rules structurizr--indent-rules)

  (treesit-major-mode-setup))

(provide 'structurizr)

;;; structurizr.el ends here
