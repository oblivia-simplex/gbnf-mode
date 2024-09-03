;;; gbnf-mode.el --- Major mode for editing GBNF grammars. -*- lexical-binding: t; -*-

;; Copyright (C) 2019-2022 Free Software Foundation, Inc

;; Author: Serghei Iakovlev <egrep@protonmail.ch>
;; Maintainer: Serghei Iakovlev <egrep@protonmail.ch>
;; Version: 0.4.5
;; URL: https://github.com/oblivia-simplex/gbnf-mode
;; Keywords: languages
;; Package-Requires: ((cl-lib "0.5") (emacs "25.1"))
;; Revision: $Format:%h (%cD %d)$

;;;; License

;; This file is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;   GBNF Mode is a GNU Emacs major mode for editing GBNF grammars.  Presently it
;; provides basic syntax and font-locking for GBNF files.  GBNF notation is
;; supported exactly form as it was first announced in the ALGOL 60 report.

;;; Code:


;;;; Requirements

(eval-when-compile
  (require 'rx))    ; `rx'


;;;; Customization

;;;###autoload
(defgroup gbnf nil
  "Major mode for editing GBNF grammars."
  :tag "GBNF"
  :prefix "gbnf-"
  :group 'languages
  :link '(url-link :tag "GitHub Page" "https://github.com/sergeyklay/gbnf-mode")
  :link '(emacs-commentary-link :tag "Commentary" "gbnf-mode"))


;;;; Specialized rx

(eval-when-compile
  (defconst gbnf-rx-constituents
    `((gbnf-rule-name . ,(rx (and
                              (1+ (or alnum digit))
                              (0+ (or alnum digit
                                      (in "_-")))))))
    "Additional special sexps for `gbnf-rx'."))

  (defmacro gbnf-rx (&rest sexps)
     "GBNF-specific replacement for `rx'.

In addition to the standard forms of `rx', the following forms
are available:

`gbnf-rule-name'
      Any valid GBNF rule name.  This rule was obtained by studying
      ALGOL 60 report, where the GBNF was officially announced.
      Please note: This rule is not suitable for AGBNF or EGBNF
      (see URL `https://www.masswerk.at/algol60/report.htm').

See `rx' documentation for more information about REGEXPS param."
     (let ((rx-constituents (append gbnf-rx-constituents rx-constituents)))
       (rx-to-string (cond ((null sexps) (error "No regexp is provided"))
                           ((cdr sexps)  `(and ,@sexps))
                           (t            (car sexps)))
                     t)))


;;;; Font Locking

(defvar gbnf-font-lock-keywords
  `(
    ;; Quoted string terminals
        (,(gbnf-rx "\""
                   (0+ (not (any "\"")))
                   "\"")
         0 font-lock-string-face)
    ;; LHS nonterminals may be preceded
    ;; by an unlimited number of spaces
    (,(gbnf-rx (and line-start
                   (0+ space)
                   (group gbnf-rule-name)
                   (0+ space)
                   "::="))
     1 font-lock-function-name-face)
    ;; Other nonterminals
    (,(gbnf-rx (and (0+ space)
                   (group gbnf-rule-name)
                   (0+ space)))
     1 font-lock-builtin-face)
    ;; “may expand into” symbol
    (,(gbnf-rx (and symbol-start
                   (group "::=")
                   symbol-end))
     1 font-lock-constant-face)
    ;; Alternatives
    (,(gbnf-rx (and (0+ space)
                   symbol-start
                   (group "|")
                   symbol-end
                   (0+ space)))
     1 font-lock-warning-face)
  "Font lock GBNF keywords for GBNF Mode."))


;;;; Syntax

(defvar gbnf-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; FIXME: "_" doesn't mean "symbol" but "symbol constituent".
    ;; I.e. the settings below mean that Emacs will consider "a:b=(c" as one
    ;; symbol (aka "identifier") which can be seen if you try to C-M-f and
    ;; C-M-b to move by sexps.

    ;; Treat ::= as sequence of symbols
    (modify-syntax-entry ?\: "_" table)
    (modify-syntax-entry ?\= "_" table)

    ;; Treat | as a symbol
    (modify-syntax-entry ?\| "_" table)

    ;; Curly braces are just treated as symbols
    (modify-syntax-entry ?\{ "_" table)
    (modify-syntax-entry ?\} "_" table)

    ;; Group angle brackets
    (modify-syntax-entry ?\< "(>" table)
    (modify-syntax-entry ?\> ")<" table)

    ;; Group square brackets
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)

    ;; Group parentheses
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)

    ;; Comments are begins with “#” and ends with “\n”
    (modify-syntax-entry ?\# "<" table)
    (modify-syntax-entry ?\n ">" table)

    table)
  "Syntax table in use in `gbnf-mode' buffers.")


;;;; Initialization

;;;###autoload
(define-derived-mode gbnf-mode prog-mode "GBNF"
  "A major mode for editing GBNF grammars.

\\{gbnf-mode-map}

Turning on GBNF Mode calls the value of `prog-mode-hook' and then of
`gbnf-mode-hook', if they are non-nil."
  :syntax-table gbnf-mode-syntax-table

  ;; Comments setup
  (setq-local comment-use-syntax nil)
  (setq-local comment-start "# ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?:\\(\\W\\|^\\);+\\)\\s-+")

  ;; Font locking
  (setq font-lock-defaults
        '(
          ;; Keywords
          gbnf-font-lock-keywords
          ;; keywords-only
          nil
          ;; According to RFC5234 rule names are case insensitive.
          ;; The names <rulename>, <Rulename>, <RULENAME>, and <rUlENamE>
          ;; all refer to the same rule.  As far as is known, this doesn't
          ;; conflict with original GBNF version
          ;; (see URL `https://tools.ietf.org/html/rfc5234')
          t)))

;; Invoke gbnf-mode when appropriate

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.gbnf\\'" . gbnf-mode))

(provide 'gbnf-mode)
;;; gbnf-mode.el ends here
