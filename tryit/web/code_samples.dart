final samples = {
  'util/functions.lox': r'''let eq = \a -> \b -> a == b;
''',
'util/lists.lox': r'''let {plus} = import "numeric.lox";
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

let join = fold("", String.concat);''',
'util/numeric.lox': r'''
let abs_diff = \a, b -> a > b ? a - b : b - a;
let abs = \a -> a >= 0 ? a : a * -1;
let plus = \a, b -> a + b;
let minus = \a, b -> a - b;
let sign = \n {
    if n == 0 then return 0;
    if n < 0 then return -1;
    assert n > 0;
    return 1;
};''',
'advent_of_code_2021_day_2.lox': r'''let {fold, map, join} = import "util/lists.lox";

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
''',
'advent_of_code_2024_day_1.lox': r'''let {fold, count_where, zip, sort, sum, first, rest} = import "util/lists.lox";
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

assert answer2 == 31;''',
'advent_of_code_2024_day_2.lox': r'''let {zip_with_tail, count_where, first, all, enumerated, fold_until, drop_at, map, any} = import "util/lists.lox";
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
''',
'patterns.lox': r'''let {join} = import "util/lists.lox";

let describe = \{as_of: current_year} -> \robot {
    let {
        name: { label },
        manufacture_date: { year: creation_year },
        serial_number,
    } = robot;
    let is_old_tech = current_year - creation_year > 1;
    return [label, " - ", serial_number, is_old_tech ? " (VINTAGE)" : " (NEW)"] \> join;
};

let robot = {
    name: {
        label: "a",
        title: "b",
        version: "c",
    },
    manufacture_date: {
        year: 2020,
        month: 01,
        day: 01,
    },
    serial_number: "abc123",
};

let description = robot \> describe({as_of: 2025});
print description;
assert description == "a - abc123 (VINTAGE)";


let _ = 1;
let _ = 1;
let _ = "1";
let discard_param = \_ -> 1;
assert discard_param("f") == 1;
assert discard_param([]) == 1;

let f01 = \{a} -> 1+a;
let f02 = \{a} { return 1+a; };
let f03 = \{a: b} -> 1+b;
let f04 = \{a: b} { return 1+b; };

assert f01({a: 1}) == 2;
assert f02({a: 1}) == 2;
assert f03({a: 1}) == 2;
assert f04({a: 1}) == 2;

let f06 = \x, {a} -> 1+a+x;
let f07 = \x, {a} { return 1+a+x; };
let f08 = \x, {a: b} -> 1+b+x;
let f09 = \x, {a: b} { return 1+b+x; };

assert f06(1, {a: 1}) == 3;
assert f07(1, {a: 1}) == 3;
assert f08(1, {a: 1}) == 3;
assert f09(1, {a: 1}) == 3;

let f10 = \{a}, x -> 1+a+x;
let f11 = \{a}, x { return 1+a+x; };
let f12 = \{a: b}, x -> 1+b+x;
let f13 = \{a: b}, x { return 1+b+x; };

assert f10({a: 1}, 1) == 3;
assert f11({a: 1}, 1) == 3;
assert f12({a: 1}, 1) == 3;
assert f13({a: 1}, 1) == 3;

''',
'return_expr.lox': r'''let unlucky = \ -> false;
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
''',
'tags.lox': r'''
let tab = .Key("\t");
let center = .Mouse({x: 50, y: 50});
let key_or_mouse = false ? tab : center;

let fn = \e -> match e {
    .Key(char) -> char,
    .Mouse({x}) -> x > 50 ? "top" : "bottom",
};

print fn(tab);
print fn(center);
print fn(key_or_mouse);

let colors = [.Green, .Gold, .Red];
let fav_color = colors \> List.first;
print match fav_color {
    .Green -> "green",
    .Gold -> "gold",
    .Red -> "red",
};

assert match fav_color { .Gold -> 1, _ -> 2 } == 2;

assert match [
    .Dark(.Some("oh")),
    .Light(.None),
    .Dark(.None),
    .Dark(.Some("hi")),
    .Dark(.None),
    .Light(.Some("ok")),
    .Light(.Some("yep")),
] \> List.first {
    .Light(str)-> match str {
        .Some(_) -> 1,
        .None -> 2,
    },
    .Dark(str) -> match str {
        .Some(_) -> 3,
        .None -> 4,
    },
} == 3;

assert match [
    .Dark({title: .Some("oh"), subtitle: "hmm"}),
    .Light({title: .None, subtitle: "hmm"}),
    .Dark({title: .None, subtitle: "hmm"}),
    .Dark({title: .Some("hi"), subtitle: "hmm"}),
    .Dark({title: .None, subtitle: "hmm"}),
    .Light({title: .Some("ok"), subtitle: "hmm"}),
    .Light({title: .Some("yep"), subtitle: "hmm"}),
] \> List.first {
    .Light({title}) -> match title {
        .Some(_) -> 1,
        .None -> 2,
    },
    .Dark({title}) -> match title {
        .Some(_) -> 3,
        .None -> 4,
    },
} == 3;

assert match [
    .Dark({title: .Some("oh"), subtitle: "hmm"}),
    .Light({title: .None, subtitle: "hmm"}),
    .Dark({title: .None, subtitle: "hmm"}),
    .Dark({title: .Some("hi"), subtitle: "hmm"}),
    .Dark({title: .None, subtitle: "hmm"}),
    .Light({title: .Some("ok"), subtitle: "hmm"}),
    .Light({title: .Some("yep"), subtitle: "hmm"}),
] \> List.first {
    .Dark({title})  -> 1,
    .Light({title}) -> 2,
} == 1;
'''
};
