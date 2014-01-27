;;; roguel-ike-controller.el --- Controllers' code

;; Copyright (C) 2014 Steven Rémot

;;; Author: Steven Rémot

;;; License:
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
;; Define roguel-ike controls system

;;; Code:

(require 'eieio)
(require 'roguel-ike-game)
(require 'roguel-ike-graphics)
(require 'roguel-ike-fov)
(require 'roguel-ike-behaviour)

(defvar-local rlk-controller nil
  "Game controller associated to the buffer.")

(defclass rlk--controller-game ()
  ((game :initarg :game
         :type rlk--game
         :reader get-game
         :protection :private
         :documentation "Game state.")
   (renderer :initarg :renderer
             :type rlk--graphics-renderer-game
             :reader get-renderer
             :protection :private
             :documentation "Level renderer.")
   (key-bindings :initarg :key-bindings
                 :initform (("h" . move-left)
                            ("j" . move-down)
                            ("k" . move-up)
                            ("l" . move-right)
                            ("y" . move-left-up)
                            ("b" . move-left-down)
                            ("u" . move-right-up)
                            ("n" . move-right-down)
                            ("." . wait)
                            ("c" . close-door)
                            ("q" . quit-rlk))
                 :type list
                 :reader get-key-bindings
                 :protection :private
                 :documentation "Game controls."))
  "In-game controller.")

(defmacro rlk--defcommand (name args docstring &rest body)
  "Create a method for a controller, and create the associated command.
The method is named NAME, and the command rlk-command-NAME.
The kind of controller on which it should be applied is specified
by ARGS
DOCSTRING is the documentation fo the method.
BODY is the method definition."
  (declare (indent defun))
  (list
   'progn
   (append (list 'defmethod name args docstring) body)
   (list 'defun
         (intern (concat "rlk-command-" (symbol-name name)))
         '()
         docstring
         '(interactive)
         (list name 'rlk-controller))
   ))

(defmethod get-hero ((self rlk--controller-game))
  "Return the hero in the game associated to the controller."
  (get-hero (get-game self)))

(defmethod get-hero-behaviour ((self rlk--controller-game))
  "Return the hero's behaviour for the game associated to the controller."
  (get-behaviour (get-hero self)))

;; TODO try to displace fov elsewhere
(defmethod call-renderers ((self rlk--controller-game))
  "Ask the renderer to render game's level."
  (let* ((game (get-game self))
        (level (get-current-level game))
        (hero (get-hero game)))
    (rlk--fov-apply level hero)
    (draw-level (get-renderer self) level)))

(defvar rlk--direction-map
  '((move-left . (-1 . 0))
    (move-right . (1 . 0))
    (move-up . (0 . -1))
    (move-down . (0 . 1))
    (move-left-up . (-1 . -1))
    (move-left-down . (-1 . 1))
    (move-right-up . (1 . -1))
    (move-right-down . (1 . 1)))
  "Mapping between command names and direction.")

;; Direction commands definition
(dolist (direction-cons rlk--direction-map)
  (eval `(rlk--defcommand ,(car direction-cons) ((self rlk--controller-game))
                  "Move the hero."
                  (interact-with-cell (get-hero-behaviour self)
                                      ,(cadr direction-cons)
                                      ,(cddr direction-cons)))))

(rlk--defcommand wait ((self rlk--controller-game))
  "Wait one turn without doing anything."
  (wait (get-hero-behaviour self)))

(rlk--defcommand close-door ((self rlk--controller-game))
  "Ask the user for a direction, and try to close a door in this direction."
  (call-with-direction self (apply-partially 'close-door (get-hero-behaviour self))))

(rlk--defcommand quit-rlk ((self rlk--controller-game))
  "Quit roguel-ike."
  (kill-buffers (get-buffer-manager (get-game self))))

(defmethod call-with-direction ((self rlk--controller-game) function)
  "Ask the user for a direction and execute FUNCTION with the provided direction.

The direction takes the form of two arguments: dx and dy.

If the user did not enter a direction, FUNCTION is not executed, and
an error message is displayed."
  (let (direction)
    ;; Deferred assignation is required.
    ;; ask-direction is not effective otherwise.
    (setq direction  (ask-direction self))
    (if direction
        (funcall function (car direction) (cdr direction))
      (message "This is not a valid direction."))))

(defmethod ask-direction ((self rlk--controller-game))
  "Ask the user to input a direction.
If a direction is given, return a cons representing it.
Otherwise, return nil."
  (let* ((input (read-key-sequence "Enter a direction: "))
         (key (if (stringp input)
                  (substring input 0 1)
                (nth 0 input)))
         (command (cdr (assoc key (get-key-bindings self)))))
    (if command
        (let ((direction-cons (assoc command rlk--direction-map)))
          (if direction-cons
              (cdr direction-cons)
            nil))
      nil)))


(defmethod setup ((self rlk--controller-game))
  "Initiates key binding on controller"
  (with-current-buffer (get-target-buffer (get-renderer self))
    (setq rlk-controller self)
    (dolist (binding (get-key-bindings self))
      (local-set-key (car binding)
                     (intern (concat "rlk-command-"
                                          (symbol-name (cdr binding))))))))


(provide 'roguel-ike-controller)
;;; roguel-ike-controller.el ends here
