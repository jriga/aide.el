;;; aide.el --- An Emacs front end for GPT APIs like OpenAI  -*- lexical-binding: t; -*-

;; Copyright (C) 2021  Junji Zhi

;; Author: Junji Zhi
;; Keywords: gpt-3 openai

;; This program is free software; you can redistribute it and/or modify
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

;; Simple wrapper to call GPT APIs
;;
;; For details, please see http://github.com/junjizhi/aide.el

;;; Code:

(require 'request) ;; M-x package-install RET request RET

(defgroup aide nil
  "aide.el custom settings"
  :group 'external
  :prefix "aide-")

(defcustom aide-max-input-tokens 3800
  "The maximum number of tokens that aide.el sends to OpenAI API"
  :type 'integer
  :group 'aide)

(defcustom aide-max-output-tokens 100
  "The max-tokens paramater that aide.el sends to OpenAI API."
  :type 'integer
  :group 'aide)

(defcustom aide-temperature 0
  "The temperature paramater that aide.el sends to OpenAI API."
  :type 'float
  :group 'aide)

(defcustom aide-top-p 0.1
  "The top-p paramater that aide.el sends to OpenAI API."
  :type 'float
  :group 'aide)

(defcustom aide-frequency-penalty 0
  "The frequency_penalty paramater that aide.el sends to OpenAI API."
  :type 'float
  :group 'aide)

(defcustom aide-presence-penalty 0
  "The presence_penalty paramater that aide.el sends to OpenAI API."
  :type 'float
  :group 'aide)

(defcustom aide-completions-model "text-davinci-003"
  "Name of the model used for completions. aide sends requests to
   the OpenAI API endpoint of this model."
  :type 'string
  :group 'aide
  :options '("text-davinci-003", "text-curie-001", "text-babbage-001", "text-ada-001", "code-davinci-002", "code-cushman-001"))

(defun aide-openai-complete (api-key prompt)
  "Return the prompt answer from OpenAI API.
   API-KEY is the OpenAI API key.
   PROMPT is the prompt string we send to the API."
  (let ((result nil)
	(auth-value (format "Bearer %s" api-key)))
    (request
      "https://api.openai.com/v1/completions"
      :type "POST"
      :data (json-encode `(("prompt" . ,prompt)
			   ("model"  . ,aide-completions-model)
			   ("max_tokens" . ,aide-max-output-tokens)
			   ("temperature" . ,aide-temperature)
			   ("frequency_penalty" . ,aide-frequency-penalty)
			   ("presence_penalty" . ,aide-presence-penalty)
			   ("top_p" . ,aide-top-p)))
      :headers `(("Authorization" . ,auth-value) ("Content-Type" . "application/json"))
      :sync t
      :parser 'json-read
      :success (cl-function
		(lambda (&key data &allow-other-keys)
		  (setq result (alist-get 'text (elt (alist-get 'choices data) 0)))))
      :error (cl-function (lambda (&rest args &key error-thrown &allow-other-keys)
		 (message "Got error: %S" error-thrown))))
      result))

(defun aide-openai-complete-region (start end)
  "Send the region to OpenAI autocomplete engine and get the result.
   START and END are selected region boundaries."
       (interactive "r")
       (let* ((region (buffer-substring-no-properties start end))
	      (result (aide--openai-complete-string region)))
	 (message "%s" result)))

(defun aide-openai-complete-region-insert (start end)
  "Send the region to OpenAI and insert the result to the end of buffer.
   START and END are selected region boundaries."
  (interactive "r")
  (let* ((region (buffer-substring-no-properties start end))
	 (result (aide--openai-complete-string region))
	original-point)
    (goto-char (point-max))
    (setq original-point (point))
    (if result
	(progn
	  (insert "\n" result)
	  (fill-paragraph)
	  (let ((x (make-overlay original-point (point-max))))
	    (overlay-put x 'face '(:foreground "orange red")))
	  result)
      (message "Empty result"))))

(defun aide-openai-complete-buffer-insert ()
  "Send the ENTIRE buffer, up to max tokens, to OpenAI and insert the result to the end of buffer."
  (interactive)
  (let (region
	result
	original-point)
    (setq region (buffer-substring-no-properties (get-min-point) (point-max)))
    (setq result (aide--openai-complete-string region))
    (goto-char (point-max))
    (setq original-point (point))
    (if result
	(progn
	  (insert "\n" result)
	  (fill-paragraph)
	  (let ((x (make-overlay original-point (point-max))))
	    (overlay-put x 'face '(:foreground "orange red")))
	  result)
      (message "Empty result"))))

(defun aide-openai-tldr-region (start end)
  "Send the region to OpenAI autocomplete engine and get the TLDR result.

START and END are selected region boundaries."
  (interactive "r")
  (let* ((region (buffer-substring-no-properties start end))
	 (result (aide--openai-complete-string (concat region "\n\n tl;dr:"))))
    (message "%s" result)))

(defun aide-openai-edits (api-key instruction input)
  "Return the edits answer from OpenAI API.
   API-KEY is the OpenAI API key.
   INSTRUCTION and INPUT are the two params we send to the API."
  (let ((result nil)
	(auth-value (format "Bearer %s" api-key)))
    (request
      "https://api.openai.com/v1/engines/text-davinci-edit-001/edits"
      :type "POST"
      :data (json-encode `(("input" . ,input)
			   ("instruction" . ,instruction)
			   ("temperature" . 0.9)))
      :headers `(("Authorization" . ,auth-value)
		 ("Content-Type" . "application/json"))
      :sync t
      :parser 'json-read
      :success (cl-function
		(lambda (&key data &allow-other-keys)
		  (setq result (alist-get 'text (elt (alist-get 'choices data) 0))))))
    result))

(defun aide-openai-edits-region-insert (start end)
  "Send the region to OpenAI edits and insert the result to the end of region.
   START and END are selected region boundaries."
  (interactive "r")
  (let* ((region (buffer-substring-no-properties start end))
	 (result (aide-openai-edits openai-api-key "Rephrase the text" region)))
    (goto-char end)
    (if result
	(progn
	  (insert "\n" result)
	  (fill-paragraph)
	  (let ((x (make-overlay end (point))))
	    (overlay-put x 'face '(:foreground "orange red")))
	  result)
      (message "Empty result"))))

(defun aide-openai-edits-region-replace (start end)
  "Send the region to OpenAI edits and replace the region.
   START and END are selected region boundaries.
   The original content will be stored in the kill ring."
  (interactive "r")
  (let* ((region (buffer-substring-no-properties start end))
	 (result (aide-openai-edits openai-api-key "Rephrase the text" region)))
    (goto-char end)
    (if result
	(progn
	  (kill-region start end)
	  (insert "\n" result)
	  (fill-paragraph)
	  (let ((x (make-overlay end (point))))
	    (overlay-put x 'face '(:foreground "orange red")))
	  result)
      (message "Empty result"))))

;; private

(defun aide--openai-complete-string (string)
  (aide-openai-complete openai-api-key string))

(defun get-min-point ()
  "OpenAI API limits requests of > ~4000 tokens (model-specific; davinci
   maxes out at request of 4000 tokens; ~15200 char"
  (if (> (buffer-size) (* 4 (or aide-max-input-tokens 3800))) ;; 1 tokens = ~4 char
      (- (point-max) (* 4 (or aide-max-input-tokens 3800)))
    (point-min)))

(provide 'aide)
;;; aide.el ends here
