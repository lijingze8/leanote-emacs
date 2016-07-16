;;; leanote.el --- Minor mode for leanote in markdown file.  -*- lexical-binding: t; -*-

;; Copyright (C) 2016 Aborn Jiang

;; Author: Aborn Jiang <aborn.jiang@gmail.com>
;; Version: 0.1
;; Package-Requires: ((cl-lib "0.5") (request "0.2") (let-alist "1.0.3"))
;; Keywords: leanote, note, markdown
;; Homepage: https://github.com/aborn/leanote-mode
;; URL: https://github.com/aborn/leanote-mode

;; This file is NOT part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; emacs use leanote

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'request)
(require 'let-alist)

;;;;  Variables

;; for debug
(defvar leanote-debug-data nil)

;; user info
(defvar leanote-user nil)
(defvar leanote-user-password nil)
(defvar leanote-user-email nil)
(defvar leanote-user-id nil)
(defvar leanote-token nil)

;; local cache 
(defvar leanote-current-all-note-books nil)
(defvar leanote-current-note-book nil)
;; notebook-id -> notes-list(without content) map
(defvar leanote--cache-notebookid-notes (make-hash-table :test 'equal))
;; notebook-id -> notebook-info map
(defvar leanote--cache-notebookid-info (make-hash-table :test 'equal))
;; local-path -> notebook-id
(defvar leanote--cache-notebook-path-id (make-hash-table :test 'equal))

;; persistent
(defvar leanote-persistent-directory
  (let ((dir (concat user-emacs-directory ".cache/")))
    (make-directory dir t)
    dir))

;; api
(defvar leanote-api-login "/auth/login")
(defvar leanote-api-getnotebooks "/notebook/getNotebooks")
(defvar leanote-api-getnotecontent "/note/getNoteContent")
(defvar leanote-api-getnoteandcontent "/note/getNoteAndContent")
(defvar leanote-api-getnotes "/note/getNotes")

(defcustom leanote-api-root "https://leanote.com/api"
  "api root"
  :group 'leanote
  :type 'string)

(defcustom leanote-request-timeout 10
  "Timeout control for http request, in seconds."
  :group 'leanote
  :type 'number)

(defcustom leanote-local-root-path "~/leanote/note"
  "local leanote path"
  :group 'leanote
  :type 'string)

(defgroup leanote nil
  "leanote mini group"
  :prefix "leanote-"
  :group 'external)

(define-minor-mode leanote
  "leanote mini mode"
  :init-value nil
  :lighter " leanote "
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c u") 'leanote-push-current-file-to-remote)
            map)
  :group 'leanote)

(defun leanote-sync ()
  "init it"
  (interactive)
  (message "--------start to sync leanote data:%s-------" (leanote--get-current-time-stamp))
  (unless leanote-token
    (leanote-login))
  (leanote-get-note-books)
  ;; keep all notebook node info and store to hash table first
  (cl-loop for elt in (append leanote-current-all-note-books nil)
           collect
           (let* ((notebookid (assoc-default 'NotebookId elt)))
             (puthash notebookid elt leanote--cache-notebookid-info)))
  (leanote-mkdir-notebooks-directory-structure leanote-current-all-note-books)
  (cl-loop for elt in (append leanote-current-all-note-books nil)
           collect
           (let* ((title (assoc-default 'Title elt))
                  (notebookid (assoc-default 'NotebookId elt))
                  (notes (leanote-get-notes notebookid)))
             (puthash notebookid notes leanote--cache-notebookid-notes)
             (message "notebook-name:%s, nootbook-id:%s, has %d notes."
                      title notebookid (length notes))
             (leanote-create-notes-files title notes notebookid)))
  (message "--------finished sync leanote data:%s-------" (leanote--get-current-time-stamp)))

(defun leanote--get-current-time-stamp ()
  "get current time stamp"
  (format-time-string "%Y-%m-%d %H:%M:%S" (current-time)))

(defun leanote-create-notes-files (notebookname notes notebookid)
  "create&update all notes content in notebookname"
  (let* ((notebookroot (expand-file-name
                        (leanote-get-notebook-parent-path notebookid)
                        leanote-local-root-path)))
    (puthash notebookroot notebookid leanote--cache-notebook-path-id)
    (message "notebookroot=%s" notebookroot)
    (cl-loop for note in (append notes nil)
             collect
             (let* ((noteid (assoc-default 'NoteId note))
                    (title (assoc-default 'Title note))
                    (is-markdown-content (assoc-default 'IsMarkdown note))
                    (notecontent-obj (leanote-get-note-content noteid))
                    (notecontent (assoc-default 'Content notecontent-obj)))
               ;; (message "ismarkdown:%s, title:%s, content:%s" is-markdown-content title notecontent)
               (when (eq t is-markdown-content)
                 (save-current-buffer
                   (let* ((filename (concat title ".md"))
                          (file-full-name (expand-file-name filename notebookroot)))
                     (if (file-exists-p file-full-name)
                         (message "file %s already exists." file-full-name)
                       (progn (find-file file-full-name)
                              (insert notecontent)
                              (save-buffer)
                              (message "ok, file %s finished!" file-full-name))))))))))

(defun leanote-get-note-info-base-note-full-name (full-file-name)
  "get note info base note full name"
  (unless (string-suffix-p ".md" full-file-name)
    (error "file %s is not markdown file." full-file-name))
  (let* ((note-info nil)   ;; fefault return
         (notebook-id (gethash
                       (substring default-directory 0 (- (length default-directory) 1))
                       leanote--cache-notebook-path-id))
         (note-title (string-remove-suffix ".md"
                                           (string-remove-prefix
                                            default-directory
                                            full-file-name)))
         (notebook-notes nil))
    (unless notebook-id
      (error "sorry, cannot find any notes for notebook-id %s. %s"
             notebook-id
             "make sure this file is leanote file and you have login."))
    (setq notebook-notes (gethash notebook-id leanote--cache-notebookid-notes))
    (cl-loop for elt in (append notebook-notes nil)
             collect
             (when (equal note-title (assoc-default 'Title elt))
               (setq note-info elt))
             )
    note-info))

(defun leanote-push-current-file-to-remote ()
  "push current content to remote server"
  (interactive)
  (let* ((note-info (leanote-get-note-info-base-note-full-name (buffer-file-name))))
    (unless note-info
      (error "cannot find current note info in local cache."))
    (setq leanote-debug-data note-info)
    (leanote-ajax-update-note note-info (buffer-string))
    )
  )

(defun leanote-ajax-update-note (note-info note-content)
  "update note"
  (let* ((result nil)
         (usn (assoc-default 'Usn leanote-debug-data))
         (new-usn (+ 1 usn))
         (new-usn-str (number-to-string usn))
         (note-id (assoc-default 'NoteId note-info))
         (notebook-id (assoc-default 'NotebookId note-info))
         (note-title (assoc-default 'Title note-info)))
    (request (concat leanote-api-root "/note/updateNote")
             :params `(("token" . ,leanote-token)
                       ("NoteId" . ,note-id)
                       ("Usn" . ,new-usn-str)
                       ("NotebookId" . ,notebook-id)
                       ("Title" . ,note-title)
                       ("Content" . ,note-content))
             :sync t
             :type "POST"
             :parser 'leanote-parser
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (setq leanote-debug-data data)  ;; TODO
                         (when (and (listp data)
                                    (equal :json-false (assoc-default 'Ok data)))
                           (error "push to remote error, msg:%s" (assoc-default 'Msg data)))
                         (setq result data))))
    result))

(defun leanote-parser ()
  "parser"
  (json-read-from-string (decode-coding-string (buffer-string) 'utf-8)))

(defun leanote-get-note-content (noteid)
  "get note content, return type.Note"
  (interactive)
  (leanote-common-api-action leanote-api-getnotecontent "noteId" noteid))

(defun leanote-get-notes (notebookid)
  "get notebook notes list"
  (interactive)
  (leanote-common-api-action leanote-api-getnotes "notebookId" notebookid))

(defun leanote-get-note-and-content (noteid)
  "get note and content, return  type.Note"
  (interactive)
  (leanote-common-api-action leanote-api-getnoteandcontent "noteId" noteid))

(defun leanote-common-api-action (api &optional param-key &optional param-value)
  "common api only one parameter"
  (let ((result nil))
    (request (concat leanote-api-root api)
             :params `(("token" . ,leanote-token) (,param-key . ,param-value))
             :sync t
             :parser 'leanote-parser
             :success (cl-function
                       (lambda (&key data &allow-other-keys)
                         (setq leanote-debug-data data)  ;; TODO
                         (if (arrayp data)
                             (setq result data)
                           (progn (unless (eq (assoc-default 'Ok leanote-debug-data) :json-false)
                                    (setq result data))
                                  )))))
    result))

(defun leanote-get-note-books ()
  "get note books"
  (interactive)
  (let ((note-books (leanote-common-api-action leanote-api-getnotebooks)))
    (when note-books
      (setq leanote-current-all-note-books note-books)
      (message "Got %d notebooks." (length note-books))
      note-books)))

;; (leanote-get-notebook-parent-path "5789af43c3b1f40b51000009")
;; "其他笔记/其他语言学习"
(defun leanote-get-notebook-parent-path (parentid)
  "get notebook parent path"
  (let* ((cparent (gethash parentid leanote--cache-notebookid-info))
         (cparent-title (assoc-default 'Title cparent))
         (cparent-parent-id (assoc-default 'ParentNotebookId cparent))
         (cparent-no-parent (string= "" cparent-parent-id)))
    (if cparent-no-parent
        cparent-title
      (concat (leanote-get-notebook-parent-path cparent-parent-id) "/" cparent-title))
    ))

(defun leanote-mkdir-notebooks-directory-structure (&optional all-notebooks)
  "make note-books hierarchy"
  (interactive)
  (unless (file-exists-p leanote-local-root-path)
    (message "make root dir %s" leanote-local-root-path)
    (make-directory leanote-local-root-path t))
  (when (null all-notebooks)
    (message "all-notebooks not provided.")

    (setq all-notebooks leanote-current-all-note-books))
  (cl-loop for elt in (append all-notebooks nil)
           collect
           (let* ((title (assoc-default 'Title elt))
                  (notebook-id (assoc-default 'NotebookId elt))
                  (parent-id (assoc-default 'ParentNotebookId elt))
                  (has-parent (not (string= "" parent-id)))
                  (current-notebook-path (expand-file-name title leanote-local-root-path)))
             (message "title=%s" title)
             (when has-parent
               (message "title=%s has parent" title)
               (setq current-notebook-path (expand-file-name
                                            (leanote-get-notebook-parent-path notebook-id)
                                            leanote-local-root-path)))
             (unless (file-exists-p current-notebook-path)
               (message "notebook:%s, path:%s" title current-notebook-path)
               (make-directory current-notebook-path t)
               ))
           ))

(defun leanote-login (&optional user password)
  "login in leanote"
  (interactive)
  (when (null user)
    (setq user (read-string "Email: " nil nil leanote-user-email)))
  (when (null password)
    (setq password (read-passwd "Password: " nil leanote-user-password)))
  (request (concat leanote-api-root leanote-api-login)
           :params `(("email" . ,user)
                     ("pwd" . ,password))
           :sync t
           :parser 'leanote-parser
           :success (cl-function
                     (lambda (&key data &allow-other-keys)
                       (if (equal :json-false (assoc-default 'Ok data))
                           (message "%s" (assoc-default 'Msg data))
                         (progn
                           (setq leanote-token (assoc-default 'Token data))
                           (setq leanote-user (assoc-default 'Username data))
                           (setq leanote-user-email (assoc-default 'Email data))
                           (setq leanote-user-id (assoc-default 'UserId data))
                           (setq leanote-user-password password) ;; update password
                           (message "login success!")))))))

(provide 'leanote)
;;; leanote.el ends here
