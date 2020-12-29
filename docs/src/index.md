# CollegeStratCollege

This package collects the college related code for the `CollegeStrat` project.

A college consists of

- a dropout rule
- a graduation rule
- a course grid
- a human capital production function
- a human capital shock process
- a learning specification that determines how learning is split between the two types of human capital
- a tuition function
- choice sets for study and work times
- and some other details

## Dropout rule

The dropout rule determines when a student must drop out of college.

```@docs
DropoutRule
DropoutRuleSet
DropoutRuleSwitches
DropoutRuleSimple
DropoutRuleSetSimple 
DropoutRuleSwitchesSimple
make_dropout_set
make_dropout_rule
drop_prob
drop_prob_grid
```

## Graduation Rule

The graduation rule gives the probability that a student may graduate at the end of each year in college.

## Course grid

The course grid determines the number of courses a student make take in each period.

## Human capital production function

This determines how much students learn in college.



-----------