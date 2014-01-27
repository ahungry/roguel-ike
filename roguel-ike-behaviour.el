;;; roguel-ike-behaviour.el --- Entities' behaviour

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
;; The in-world representation of an entity and its behaviour
;; are clearly separated.  The behaviour of an entity is the
;; object that decides what an entity should do now, regarding
;; its current environment.

;;; Code:

(require 'eieio)
(require 'roguel-ike-entity)

;;;;;;;;;;;;;;;;
;; Base class ;;
;;;;;;;;;;;;;;;;

(defclass rlk--behaviour ()
  ((entity :reader get-entity
           :writer set-entity
           :protection :private
           :documentation "THe tntiy the current behaviour controls."))
  "Base class for behaviour objects."
  :abstract t)

(defmethod do-action ((self rlk--behaviour) callback)
  "Decide which action should be done now.
Must call callback with the number of turns the action takes."
  (error "Method do-action for behaviour must be overriden"))

(defmethod is-manual-p ((self rlk--behaviour))
  "Return t if the behaviour is manual, nil otherwise."
  nil)

;;;;;;;;;;;;;;;;;;
;; Manual class ;;
;;;;;;;;;;;;;;;;;;

(defgeneric call-renderers (controller)
  "Call the game's renderers.")

(defvar-local rlk-controller nil)

(defclass rlk--behaviour-manual (rlk--behaviour)
  ((time-callback :type function
                  :reader get-time-callback
                  :protection :private
                  :documentation "The callback sent by the time manager."))
  "Behaviour of entities controlled by the player.")

(defmethod is-manual-p ((self rlk--behaviour-manual))
  "See rlk--behaviour."
  t)

(defmethod get-controller ((self rlk--behaviour-manual))
  "Return the behaviour's controller.

It would be more elegant to avoid using the global variable, but it leads to
cyclic dependencies.

behaviour <-- hero <--- game <-- controller
   |---------------------------------A"
  rlk-controller)

(defmethod interact-with-cell ((self rlk--behaviour-manual) dx dy)
  "Try all sort of interaction with cell at DX, DY.

If cell is accessible, will move to it.
If not, and it has a door, will open it.

Apply the time callback."
  (let ((entity (get-entity self)))
    (funcall (oref self time-callback)
             (let* ((cell (get-neighbour-cell entity dx dy)))
               (if (is-accessible-p cell)
                   (if (try-move entity dx dy)
                       1
                     0)
                 (if (is-container-p cell)
                     (if (has-entity-p cell)
                         (progn
                           (attack (get-entity self) (get-entity cell))
                           1)
                       (catch 'time
                         (dolist (object (get-objects cell))
                           (when (equal (get-type object) :door-closed)
                             (do-action object entity :open)
                             (display-message entity "You open the door.")
                             (throw 'time 1)))
                         0))
                   0))))))

(defmethod wait ((self rlk--behaviour-manual))
  "Wait one turn."
  (funcall (oref self time-callback) 1))

(defmethod do-action ((self rlk--behaviour-manual) callback)
  "Register the callback for a former use."
  (call-renderers (get-controller self))
  (oset self time-callback callback))

(defmethod close-door ((self rlk--behaviour-manual) dx dy)
  "Try to close the door in the direction DX, DY."
  (let* ((entity (get-entity self))
         (cell (get-neighbour-cell entity dx dy)))
    (if (is-container-p cell)
        (let ((door (catch 'door
                      (dolist (object (get-objects cell))
                        (when (rlk--interactive-object-door-p object)
                          (throw 'door object)))
                      nil)))
          (if door
              (if (is-opened-p door)
                  (if (not (has-entity-p cell))
                      (progn
                        (do-action door entity :close)
                        (display-message entity "You close the door.")
                        (funcall (get-time-callback self) 1))
                    (display-message entity "There is something on the way."))
                (display-message entity "The door is already closed."))
            (display-message entity "There is no door here...")))
          (display-message entity "There is no door here..."))))


;;;;;;;;;;;;;;
;; AI class ;;
;;;;;;;;;;;;;;

(defclass rlk--behaviour-ai (rlk--behaviour)
  ()
  "Behaviour of entities controlled by the computer.")


(defmethod move-randomly ((self rlk--behaviour-ai))
  "Try to move on a random neighbour cell.
Return the number of turns spent if it could move, 1 for waiting otherwise."
  (let* ((entity (get-entity self))
         (accessible-cells '())
         (level (get-level entity))
         (choosen-cell nil))
    (dotimes (i 3)
      (dotimes (j 3)
        (let*
            ((dx (- i 1))
             (dy (- j 1))
             (x (+ (get-x entity) (- i 1)))
             (y (+ (get-y entity) (- j 1)))
             (cell (get-cell-at level x y)))
          (when (is-accessible-p cell)
            (add-to-list 'accessible-cells (cons dx dy))))))
    ;; If there are accessible cells, move. Otherwise, wait.
    (when accessible-cells
      (setq choosen-cell (nth (random (length accessible-cells))
                              accessible-cells))
      (try-move entity (car choosen-cell) (cdr choosen-cell)))
      1))

(defmethod do-action ((self rlk--behaviour-ai) callback)
  "See rlk--behaviour."
  (funcall callback (move-randomly self)))



(provide 'roguel-ike-behaviour)

;;; roguel-ike-behaviour.el ends here
