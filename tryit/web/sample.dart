final sample = r'''
// Built-ins
let empty = List.empty;
let first = List.first;
let rest = List.rest;

//
// Lists
//
let friends = ["alice", "bob"];
let family = ["charlie", "devin"];
let people = ["joe", ..friends, "john", ..family];
print rest(people);

//
// Records
//
let boss = {
    name: "Bob Vance",
    company: "Vance Refrigeration",
};
let updated = {..boss, lineOfWork: .Refrigeration};
print boss;
print updated.company;
let { 
  name, 
  lineOfWork: subtitle,
} = updated;
print name;
print subtitle;

//
// Variants
//
let green = .Green;
let red = .Red;
let either = true ? green : red;
print match either {
    .Green -> 0,
    .Red -> 1,
};

let sendEmail = \x {
  if x == "a" then return .MissingSubject;
  if x == "b" then return .NetworkError(123);
  if x == "c" then return .OOM;
  return .Sent;
};
let result = match sendEmail("a") {
  .Sent           -> .Alert("success"),
  .MissingSubject -> .Alert("missing subject line"),
  somethingBad    -> somethingBad,
};

//
// Functions
//
let sub = \x, y -> x - y;
print sub(7, 2);

let oneMinusX = sub(1, _);
let xMinusOne = sub(_, 1);
print oneMinusX(3);
print xMinusOne(3);

let numbers = [1,2,3];
print numbers \> first \> sub(_, 1);

let makeUser = \data {
    if data.name == "null" then {
        print "hmm";
        return .Anonymous;
    }
    let randomId = 123;
    return .User({
        userId: randomId,
        name: data.name,
        birthYear: data.birthYear,
        ageAsOf: \currentYear -> currentYear - data.birthYear,
    });
};
let user = makeUser({name: "Bob", birthYear: 1974});
print match user {
    .User u -> u.ageAsOf(2025),
    .Anonymous -> 0,
};

''';
