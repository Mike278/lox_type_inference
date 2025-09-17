
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
let updated = {..boss, line_of_work: .refrigeration};
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
let green = .green;
let red = .red;
let either = true ? green : red;
print match either {
    .green -> 0,
    .red -> 1,
};

let send_email = \x {
  if x == "a" then return .missing_subject;
  if x == "b" then return .network_error(123);
  if x == "c" then return .oom;
  return .sent;
};
let result = match send_email("a") {
  .sent            -> .alert("success"),
  .missing_subject -> .alert("missing subject line"),
  something_bad    -> something_bad,
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
        return .anonymous;
    }
    let random_id = 123;
    return .user({
        user_id: random_id,
        name: data.name,
        birth_year: data.birth_year,
        age: \{as_of_year: current_year} -> current_year - data.birth_year,
    });
};
let user = make_user({name: "Bob", birth_year: 1974});
print match user {
    .user(u) -> u.age({as_of_year: 2025}),
    .anonymous -> 0,
};''')),
(SampleName('return_expr.lox'),  SampleContent(r'''let unlucky = \ -> false;
let online = \ -> false;
let is_auth_expired = \ -> false;

let connect = \ {
    if unlucky() then return .bad_luck;
    if !online() then return .offline;
    return .connection({
        some_connection_details: 123,
        download: \ -> "the data",
    });
};

let download = \connection {
    if is_auth_expired() then return .auth_expired;
    if unlucky() then return .download_interrupted;
    let result = connection.download();
    return .the_data(result);
};

let connect_and_download = \ {
    let connection = match connect() {
        .connection(c) -> c,
        .offline -> return .the_data("some default data"),
        other -> return other,
    };

    return download(connection);
};

let data = connect_and_download();
print data;
''')),
(SampleName('advent_of_code_2024_day_1.lox'),  SampleContent(r'''let {fold, try_fold, count_where, zip, sort, sum, elements, element_at} = import "util/lists.lox";
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

let initial = {list1: [], list2: []};
let {list1, list2} = input \> try_fold(
    initial,
    \state, pair {
      let {list1, list2} = state;
      let left = pair \> element_at(0);
      let right = pair \> element_at(1);
      return .ok({
        list1: [..list1, left!],
        list2: [..list2, right!],
      });
    }
) ?? initial;

print list1;
print list2;

/////// Part 1 ///////

let answer1 = zip(
  list1 \> sort,
  list2 \> sort,
  abs_diff
) \> sum;

assert answer1 == .ok(11);

/////// Part 2 ///////

let frequency_of_number_in_list2 = \n ->
    list2 \> count_where(n \> eq);

let answer2 = list1 \> fold(0, \running, n {
    let value = n * frequency_of_number_in_list2(n);
    return running + value;
});

assert answer2 == 31;''')),
(SampleName('advent_of_code_2024_day_2.lox'),  SampleContent(r'''let {elements, zip_with_tail, count_where, all, enumerated, fold_until, drop_at, map, any} = import "util/lists.lox";
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
    let first_direction = match diffs \> elements {
        .err(_) -> return false,
        .ok({first}) -> first \> sign,
    };
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
(SampleName('advent_of_code_2024_day_3.lox'),  SampleContent(r'''let {map, sum} = import "util/lists.lox";
let {split, split_at, parse_int} = import "util/strings.lox";

let parse_operand = \{until: separator} -> \str {
  let {before, after} = (str \> split_at({separator}))!;
  let number = parse_int(before)!;
  return .ok({number, rest: after});
};

let compute_product = \str ->
    str
      \> split({separator: "mul("})
      \> map(\part {
        let {number: lhs, rest} = (part \> parse_operand({until: ","}))!;
        let {number: rhs} = (rest \> parse_operand({until: ")"}))!;
        return .ok(lhs * rhs);
      })
      \> map(\product -> product ?? 0)
      \> sum;


/////// Part 1 ///////
let input1 = "xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))";
let part_1 = \ -> compute_product(input1);
let part_1_result = part_1();
print part_1_result;
assert part_1_result == .ok(161);

/////// Part 2 ///////
let input2 = "xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))";
let part_2 = \ ->
input2
  \> split({separator: "do()"})
  \> map(\part ->
       match part \> split_at({separator: "don't()"}) {
         .ok({before}) -> compute_product(before),
         .err(_) -> compute_product(part),
       }
     )
  \> map(\product -> product ?? 0)
  \> sum;

let part_2_result = part_2();
print part_2_result;
assert part_2_result == .ok(48);
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

    let {aim, pos} = state!;

    let {
        arg1: dir,
        arg2: mag,
    } = instr;

    // todo: fix type checking bug that prevents using record updates here

    if dir == "down" then return .ok({
        aim: aim + mag,
        pos,
    });

    if dir == "up" then return .ok({
        aim: aim - mag,
        pos,
    });

    if dir == "forward" then return .ok({
        aim,
        pos: {
            x: pos.x + mag,
            y: pos.y + mag * aim
        },
    });

    return .err(["unknown direction: '", dir, "' falling back to no-op"] \> join);
};

let initial = .ok({
    aim: 0,
    pos: {x: 0, y: 0},
});
let result = input \> fold(initial, update);
let part_2 = match result {
    .ok({pos: {x, y}}) -> x * y,
    .err(_) -> -1,
};

print part_2;
assert part_2 == 900;
''')),
(SampleName('util/lists.lox'),  SampleContent(r'''let {plus} = import "numeric.lox";

let elements = \list ->
    list \> List.empty
        ? .err(.empty_list)
        : .ok({
            first: list \> List.first,
            rest: list \> List.rest,
          })
;

let fold = \state, fn -> \list {
    let {first, rest} = list \> elements ?? return state;
    let new_state = fn(state, first);
    return rest \> fold(new_state, fn);
};

let try_fold = \initial, fn ->
  fold(
    .ok(initial),
    \state, element -> fn(state!, element),
  );

let map = \fn -> \list ->
    list \> fold([], \state, element -> [..state, fn(element)]);

let reduce = \fn -> \list ->
  match list \> elements {
    .err(e) -> .err(e),
    .ok({first, rest}) -> .ok(rest \> fold(first, fn))
  };

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
            list: [ ..list, { element, index } ],
        }
    );
    return result.list;
};

let count_where = \predicate -> \list ->
    list \> fold(0, \count, element -> predicate(element) ? count + 1 : count);

let sort = \list {
  let {first: x, rest: xs} = list \> elements ?? return [];
  let is_before = \e -> e < x;
  let is_after = \e -> e >= x;
  return [
    ..xs \> where(is_before) \> sort,
    x,
    ..xs \> where(is_after) \> sort
  ];
};

let zip = \list1, list2, fn {
  let l1 = list1 \> elements ?? return [];
  let l2 = list2 \> elements ?? return [];
  return [
      fn(l1.first, l2.first),
      ..zip(l1.rest, l2.rest, fn),
  ];
};

let zip_with_tail = \fn -> \list ->
  match list \> elements {
    .err(_) -> [],
    .ok({rest}) -> zip(list, rest, fn)
  };

let sum = reduce(plus);



let fold_until = \state, fn -> \list {
    let {first, rest} = list \> elements ?? return state;
    let step = fn(state, first);
    return match step {
        .continue(new_state) -> rest \> fold_until(new_state, fn),
        .break(final_state) -> final_state,
    };
};

let any = \predicate -> \list ->
    list \> fold_until(
        false,
        \state, element ->
            predicate(element)
                ? .break(true)
                : .continue(state)
    );

let all = \predicate -> \list ->
    list \> fold_until(
        true,
        \state, element ->
            predicate(element)
                ? .continue(state)
                : .break(false)
    );

let drop_at = \target_index -> \list ->
    list
        \> enumerated
        \> where(\{index} -> index != target_index)
        \> map(\{element} -> element);

let join = fold("", String.concat);

let element_at = \target_index -> \list ->
    list
        \> enumerated
        \> fold_until(
               .err(.out_of_bounds),
               \state, {index, element} ->
                 index == target_index
                   ? .break(.ok(element))
                   : .continue(state),
           );

let length = fold(0, \count, _ -> count + 1);
''')),
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
};''')),
(SampleName('util/strings.lox'),  SampleContent(r'''let { fold, join, elements, map } = import "lists.lox";

let split = \{separator} -> \str -> String.split(str, separator);

let split_at = \{separator} -> \str {
    let { first, rest } = str
      \> split({separator})
      \> elements
      ?? return .err(.separator_not_found);
    return .ok({
      before: first,
      after: rest \> join,
    });
};

let as_digit = \str ->
    str == "0" ? .ok(0) :
    str == "1" ? .ok(1) :
    str == "2" ? .ok(2) :
    str == "3" ? .ok(3) :
    str == "4" ? .ok(4) :
    str == "5" ? .ok(5) :
    str == "6" ? .ok(6) :
    str == "7" ? .ok(7) :
    str == "8" ? .ok(8) :
    str == "9" ? .ok(9) :
    .err(.invalid_digit(str));

let parse_int = \str -> str
  \> split({separator: ""})
  \> map(as_digit)
  \> fold(
    .ok(0),
    \number, digit -> .ok(number! * 10 + digit!)
  );
'''))
];
