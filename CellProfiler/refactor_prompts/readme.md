# Intro
The `refactor-measurements-libmeasure-prompt.mdc` was made with a multi-step process. I asked my agent to review previous PR diffs to understand what changes were being made to the code. Some background on the overall project goals was also provided to it. This ended up creating a number of files: some describing the architecture, some describing the best practices, and some describing the specific code changes made. The final `refactor-measurements-libmeasure-prompt.mdc` was made by asking another agent to summarize all the "refactoring learnings".
  
# How to use the prompt

## For end-to-end refactoring
```
You are tasked with refactoring the "straightenworms" module. The prompt file at ~/Desktop/rules/refactor-measurements-libmeasure-prompt.mdc describes what the ultimate goal is. You must read it and follow it.
```

## For a specific task
```
ou are tasked with refactoring the straightenworms module. The prompt file at ~/Desktop/rules/refactor-measurements-libmeasure-prompt.mdc describes what the ultimate goal is. You must read it and follow it. However, for today's objective, you must only refactor the large functions into smaller functions in the same file. 
```

# Improvements
This prompt can be made more general. Right now it focuses heavily on measurements.
