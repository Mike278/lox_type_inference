
// 
// ACHTUNG!
// ALLES TURISTEN UND NONTEKNISCHEN LOOKENSPEEPERS!
// DAS KOMPUTERMASCHINE IST NICHT FÜR DER GEFINGERPOKEN UND MITTENGRABEN! ODERWISE IST EASY TO SCHNAPPEN DER SPRINGENWERK, BLOWENFUSEN UND POPPENCORKEN MIT SPITZENSPARKEN.
// IST NICHT FÜR GEWERKEN BEI DUMMKOPFEN. DER RUBBERNECKEN SIGHTSEEREN KEEPEN DAS COTTONPICKEN HÄNDER IN DAS POCKETS MUSS.
// ZO RELAXEN UND WATSCHEN DER BLINKENLICHTEN.
// 
// 
// (its generated code dont touch )
//
//
//
// (https://en.wikipedia.org/wiki/Blinkenlights)
//
//

extension type SampleName(String _) implements String {}
extension type SampleContent(String _) implements String {}
typedef Sample = (SampleName, SampleContent);
extension SampleAPI on Sample {
  SampleName get name => $1;
  SampleContent get content => $2;
}

final samples = [
  (SampleName('grab_bag.lox'),  SampleContent(r'''// Built-ins
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
let updated = {..boss, line_of_work: .Refrigeration};
print boss;
print updated.company;
let {
  name,
  line_of_work: subtitle,
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

let send_email = \x {
  if x == "a" then return .MissingSubject;
  if x == "b" then return .NetworkError(123);
  if x == "c" then return .OOM;
  return .Sent;
};
let result = match send_email("a") {
  .Sent           -> .Alert("success"),
  .MissingSubject -> .Alert("missing subject line"),
  something_bad   -> something_bad,
};

//
// Functions
//
let sub = \x, y -> x - y;
print sub(7, 2);

let one_minus_x = sub(1, _);
let x_minus_one = sub(_, 1);
print one_minus_x(3);
print x_minus_one(3);

let numbers = [1,2,3];
print numbers \> first \> sub(_, 1);

let make_user = \data {
    if data.name == "null" then {
        print "hmm";
        return .Anonymous;
    }
    let random_id = 123;
    return .User({
        user_id: random_id,
        name: data.name,
        birth_year: data.birth_year,
        age: \{as_of_year: current_year} -> current_year - data.birth_year,
    });
};
let user = make_user({name: "Bob", birth_year: 1974});
print match user {
    .User(u) -> u.age({as_of_year: 2025}),
    .Anonymous -> 0,
};''')),
(SampleName('return_expr.lox'),  SampleContent(r'''let unlucky = \ -> false;
let online = \ -> false;
let is_auth_expired = \ -> false;

let connect = \ {
    if unlucky() then return .BadLuck;
    if !online() then return .Offline;
    return .Connection({
        some_connection_details: 123,
        download: \ -> "the data",
    });
};

let download = \connection {
    if is_auth_expired() then return .AuthExpired;
    if unlucky() then return .DownloadInterrupted;
    let result = connection.download();
    return .TheData(result);
};

let connect_and_download = \ {
    let connection = match connect() {
        .Connection(c) -> c,
        .Offline -> return .TheData("some default data"),
        other -> return other,
    };

    return download(connection);
};

let data = connect_and_download();
print data;
''')),
(SampleName('advent_of_code_2024_day_1.lox'),  SampleContent(r'''let {fold, count_where, zip, sort, sum, first, rest} = import "util/lists.lox";
let {abs_diff} = import "util/numeric.lox";
let {eq} = import "util/functions.lox";

let input = [
    [3, 4],
    [4, 3],
    [2, 5],
    [1, 3],
    [3, 9],
    [3, 3]
];

let { list1, list2 } = input \> fold(
    {list1: [], list2: []},
    \{list1, list2}, pair -> {
        list1: [..list1, pair \> first],
        list2: [..list2, pair \> rest \> first],
    }
);
print list1;
print list2;

/////// Part 1 ///////

let answer1 = zip(
  list1 \> sort,
  list2 \> sort,
  abs_diff
) \> sum;

assert answer1 == 11;

/////// Part 2 ///////

let frequency_of_number_in_list2 = \n ->
    list2 \> count_where(n \> eq);

let answer2 = list1 \> fold(0, \running, n {
    let value = n * frequency_of_number_in_list2(n);
    return running + value;
});

assert answer2 == 31;''')),
(SampleName('advent_of_code_2024_day_2.lox'),  SampleContent(r'''let {zip_with_tail, count_where, first, all, enumerated, fold_until, drop_at, map, any} = import "util/lists.lox";
let {minus, sign, abs} = import "util/numeric.lox";

let input = [
    [7, 6, 4, 2, 1],
    [1, 2, 7, 8, 9],
    [9, 7, 6, 2, 1],
    [1, 3, 2, 4, 5],
    [8, 6, 4, 4, 1],
    [1, 3, 6, 7, 9],
];

let is_safe = \list {
    let diffs = list \> zip_with_tail(minus);
    let first_direction = diffs \> first \> sign;
    return diffs \> all(
        \diff ->
            diff \> sign == first_direction and
            diff \> abs >= 1 and
            diff \> abs <= 3
    );
};

/////// Part 1 ///////

let part_1 = input \> count_where(is_safe);
print part_1;
assert part_1 == 2;

/////// Part 2 ///////


let part_2 = input \> count_where(
    \list ->
        list \> is_safe or
        list \> enumerated
             \> map(\{index} -> list \> drop_at(index))
             \> any(is_safe)
);
print part_2;
assert part_2 == 4;
''')),
(SampleName('advent_of_code_2021_day_2.lox'),  SampleContent(r'''let {fold, map, join} = import "util/lists.lox";

let input = [
    {arg1: "forward", arg2: 5},
    {arg1: "down",    arg2: 5},
    {arg1: "forward", arg2: 8},
    {arg1: "up",      arg2: 3},
    {arg1: "down",    arg2: 8},
    {arg1: "forward", arg2: 2},
];

let scale_by = \factor -> \{x, y} -> {
    x: x * factor,
    y: y * factor,
};

let add = \a, b -> {
    x: a.x + b.x,
    y: a.y + b.y,
};



/////// Part 1 ///////

let offset_for_direction = \dir {
    if dir == "up"      then return {y: -1, x: 0};
    if dir == "down"    then return {y: 1, x: 0};
    if dir == "forward" then return {y: 0, x: 1};
    print ["unknown direction: '", dir, "' falling back to no-op"] \> join;
    return {y: 0, x: 0};
};

let to_movement = \instr ->
    offset_for_direction(instr.arg1)
    \> scale_by(instr.arg2)
;

let part_1 = input
    \> map(to_movement)
    \> fold({y: 0, x: 0}, add)
    \> \{x, y} -> x * y
;
print part_1;
assert part_1 == 150;

/////// Part 2 ///////

let update = \state, instr {

    let {aim, pos} = match state {
        .Err(_) -> return state,
        .Ok(x) -> x,
    };

    let {
        arg1: dir,
        arg2: mag,
    } = instr;

    // todo: fix type checking bug that prevents using record updates here

    if dir == "down" then return .Ok({
        aim: aim + mag,
        pos: pos,
    });

    if dir == "up" then return .Ok({
        aim: aim - mag,
        pos: pos,
    });

    if dir == "forward" then return .Ok({
        aim: aim,
        pos: {
            x: pos.x + mag,
            y: pos.y + mag * aim
        },
    });

    return .Err(["unknown direction: '", dir, "' falling back to no-op"] \> join);
};

let initial = .Ok({
    aim: 0,
    pos: {x: 0, y: 0},
});
let result = input \> fold(initial, update);
let part_2 = match result {
    .Ok({pos: {x, y}}) -> x * y,
    .Err(_) -> -1,
};

print part_2;
assert part_2 == 900;
''')),
(SampleName('util/lists.lox'),  SampleContent(r'''let {plus} = import "numeric.lox";
let {empty, first, rest} = List;

let fold = \state, fn -> \list {
    if list \> empty then return state;
    let element = list \> first;
    let new_state = fn(state, element);
    return list \> rest \> fold(new_state, fn);
};

let map = \fn -> \list ->
    list \> fold([], \state, element -> [..state, fn(element)]);

let reduce = \fn -> \list ->
    list \> rest \> fold(list \> first, fn);

let reverse = \list ->
    list \> fold([], \state, element -> [element, ..state]);

let where = \fn -> \list ->
    list \> fold([], \state, element ->
        fn(element) ? [..state, element] : state);

let enumerated = \list {
    let result = list \> fold(
        {index: 0, list: []},
        \{index, list}, element -> {
            index: index + 1,
            list: [
                ..list,
                {
                    element: element,
                    index: index,
                }
            ],
        }
    );
    return result.list;
};

let count_where = \predicate -> \list ->
    list \> fold(0, \count, element -> predicate(element) ? count + 1 : count);

let sort = \list {
  if list \> empty then return [];
  let x = list \> first;
  let xs = list \> rest;
  let is_before = \e -> e < x;
  let is_after = \e -> e >= x;
  return [
    ..xs \> where(is_before) \> sort,
    x,
    ..xs \> where(is_after) \> sort
  ];
};

let zip = \l1, l2, fn ->
    (l1 \> empty) or
    (l2 \> empty) ? [] :
    [
        fn(l1 \> first, l2 \> first),
        ..zip(l1 \> rest, l2 \> rest, fn)
    ];

let zip_with_tail = \fn -> \list ->
    zip(list, list \> rest, fn);

let sum = reduce(plus);



let fold_until = \state, fn -> \list {
    if list \> empty then return state;
    let step = fn(state, list \> first);
    return match step {
        .Continue(new_state) -> list \> rest \> fold_until(new_state, fn),
        .Break(final_state) -> final_state,
    };
};

let any = \predicate -> \list ->
    list \> fold_until(
        false,
        \state, element ->
            predicate(element)
                ? .Break(true)
                : .Continue(state)
    );

let all = \predicate -> \list ->
    list \> fold_until(
        true,
        \state, element ->
            predicate(element)
                ? .Continue(state)
                : .Break(false)
    );

let drop_at = \target_index -> \list ->
    list
        \> enumerated
        \> where(\{index} -> index != target_index)
        \> map(\{element} -> element);

let join = fold("", String.concat);''')),
(SampleName('util/functions.lox'),  SampleContent(r'''let eq = \a -> \b -> a == b;
''')),
(SampleName('util/numeric.lox'),  SampleContent(r'''
let abs_diff = \a, b -> a > b ? a - b : b - a;
let abs = \a -> a >= 0 ? a : a * -1;
let plus = \a, b -> a + b;
let minus = \a, b -> a - b;
let sign = \n {
    if n == 0 then return 0;
    if n < 0 then return -1;
    assert n > 0;
    return 1;
};'''))
];
