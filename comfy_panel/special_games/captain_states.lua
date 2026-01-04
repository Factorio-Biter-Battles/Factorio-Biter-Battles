local Public = {}

---Represents a tri-state in the picking UI.
Public.PICKS = {
    ---Picking phase is currently running with or without active picking timer.
    ---Only applicable for one captain at a time.
    RUNNING = 0,
    ---Picking phase is currently idle. Only applicable for one captain at a
    ---time.
    IDLE = 1,
    ---Picking phase is paused. Applicable for all captains at the same time
    ---and only with active picking timer.
    PAUSED = 2,
}

return Public
