
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
  (SampleName('tour_0_records.lox'),  SampleContent(r'''// Create a record
let boss = {
    name: "Bob",
    company: "Vance Refrigeration",
};


// Access a record's fields using the dot operator
print boss.company;


// Destructure some or all of its fields
let { name } = boss;


// Optionally give destructured fields a new name
let { name: boss_name, company } = boss;


// Update an existing field
let fixed_name = {..boss, name: "Bob Vance"};

print boss.name;

print fixed_name.name;


// Add a new field
print { ..fixed_name, line_of_work: "Refrigeration" };


// You can use a variable's name as the field name - these two records are equivalent
let subtitle = "world";
let card = { title: "hello", subtitle: subtitle };
let same = { title: "hello", subtitle };
''')),
(SampleName('tour_1_variants.lox'),  SampleContent(r'''// Create a variant
let color = .green;


// Variants can union with other variants
let either = if true then color else .red;


// Variants can have a payload
let event =
    if true
    then .key("\n")
    else .mouse({ x: 50, y: 50 });


// Use the match keyword to act on each possible variant
print match either {
    .green -> 0,
    .red -> 1,
};

print match event {
    .key(char) -> char,
    .mouse({ x }) -> if x > 50 then "top" else "bottom",
};


// Or use a final catch-all branch to act on only some variants
print match either {
    .green -> .good,
    other -> other,
};

print match event {
    .key(char) -> char,
    _ -> "<ignored>"
};
''')),
(SampleName('tour_2_functions.lox'),  SampleContent(r'''// Create a function
let add_one = \x -> x + 1;


// Call a function
print add_one(5);


// Here's a function with multiple parameters and a block body
let describe = \x, y {
    let good = x or y;

    if good then print "nice";

    return good;
};


// When calling a function you can use _ to omit a parameter.
// This creates new function that takes the remaining parameter.
let always_good = describe(true, _);

print always_good(true);

print always_good(false);


// Parameters can use record destructuring to emulate named parameters.
let has_silly_name = \{ first, last } -> first == last;

print has_silly_name({ first: "Joe", last: "Joe" });


// Destructuring with an alias allows both caller and callee to use an appropriate name.
let is_new = \{ as_of_year: current_year } -> current_year > 2025;

print is_new({ as_of_year: 1999 });


// Functions can also be called with the pipeline operator
let new_user = \username -> { username, registered: true };

let grant_admin = \user -> { ..user, is_admin: true };

let display_name = \user -> if user.is_admin then "<Admin>" else user.username; 


let nested = display_name(grant_admin(new_user("Bob")));

let flat =
    "Bob"
    |> new_user
    |> grant_admin
    |> display_name
    ;
''')),
(SampleName('tour_3_errors.lox'),  SampleContent(r'''// Functions that can fail should return `.ok(data)` on success or `.err(e)` on error.
let sell_eggs = \amount, stock {

    if stock.eggs == 0
    then return .err(.out_of_stock);

    if stock.eggs < amount
    then return .err(.insufficient_stock(stock.eggs));

    let new_stock = {
        ..stock,
        eggs: stock.eggs - amount,
    };

    return .ok(new_stock);
};


// Use the ! operator inside a function to extract the payload from an `.ok` variant,
// or else return from the function with the `.err` variant.
let process = \ {
    let stock = { eggs: 5, bacon: 1 };

    let new_stock = sell_eggs(5, stock)!;

    let status =
        if new_stock.eggs < 2
        then .low_stock(new_stock.eggs)
        else .done;

    return .ok(status);
};

print match process() {

    .ok(status) -> match status {
        .done -> "no problems",
        .low_stock(_) -> "finished but low stock",
    },

    .err(e) -> match e {
        .out_of_stock -> "out of stock",
        .insufficient_stock(amount) -> "tried to buy too many"
    }
};


// Use the ?? operator to extract the payload from an `.ok` variant,
// or provide a fallback value if it's an `.err` variant.
let download = \url -> if true then .ok("some data") else .err(.offline);

print download() ?? "some default data";
''')),
(SampleName('tour_4_lists.lox'),  SampleContent(r'''// List literal syntax
let friends = ["alice", "bob"];
let family = ["charlie", "devin"];


// Use the .. operator to expand a list inside another list
let people = ["joe", ..friends, "john", ..family];


// Destructure a list
let { elements, is_empty } = import "util/lists.lox";
print match people |> elements {

    .err(_) -> "none",

    .ok({ first, rest }) ->
        if rest |> is_empty
        then String.concat("just ", first)
        else String.concat(first, " and others")
};
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
let {list1, list2} = input |> try_fold(
    initial,
    \state, pair {
      let {list1, list2} = state;
      let left = pair |> element_at(0);
      let right = pair |> element_at(1);
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
  list1 |> sort,
  list2 |> sort,
  abs_diff
) |> sum;

assert answer1 == .ok(11);

/////// Part 2 ///////

let frequency_of_number_in_list2 = \n ->
    list2 |> count_where(n |> eq);

let answer2 = list1 |> fold(0, \running, n {
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
    let diffs = list |> zip_with_tail(minus);
    let first_direction = match diffs |> elements {
        .err(_) -> return false,
        .ok({first}) -> first |> sign,
    };
    return diffs |> all(
        \diff ->
            diff |> sign == first_direction and
            diff |> abs >= 1 and
            diff |> abs <= 3
    );
};

/////// Part 1 ///////

let part_1 = input |> count_where(is_safe);
print part_1;
assert part_1 == 2;

/////// Part 2 ///////


let part_2 = input |> count_where(
    \list ->
        list |> is_safe or
        list |> enumerated
             |> map(\{index} -> list |> drop_at(index))
             |> any(is_safe)
);
print part_2;
assert part_2 == 4;
''')),
(SampleName('advent_of_code_2024_day_3.lox'),  SampleContent(r'''let {map, sum} = import "util/lists.lox";
let {split, split_at, parse_int} = import "util/strings.lox";

let parse_operand = \{until: separator} -> \str {
  let {before, after} = str |> split_at({separator})!;
  let number = parse_int(before)!;
  return .ok({number, rest: after});
};

let compute_product = \str ->
    str
      |> split({separator: "mul("})
      |> map(\part {
        let {number: lhs, rest} = part |> parse_operand({until: ","})!;
        let {number: rhs} = rest |> parse_operand({until: ")"})!;
        return .ok(lhs * rhs);
      })
      |> map(\product -> product ?? 0)
      |> sum;


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
  |> split({separator: "do()"})
  |> map(\part ->
       match part |> split_at({separator: "don't()"}) {
         .ok({before}) -> compute_product(before),
         .err(_) -> compute_product(part),
       }
     )
  |> map(\product -> product ?? 0)
  |> sum;

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
    print ["unknown direction: '", dir, "' falling back to no-op"] |> join;
    return {y: 0, x: 0};
};

let to_movement = \instr ->
    offset_for_direction(instr.arg1)
    |> scale_by(instr.arg2)
;

let part_1 = input
    |> map(to_movement)
    |> fold({y: 0, x: 0}, add)
    |> \{x, y} -> x * y
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

    return .err(["unknown direction: '", dir, "' falling back to no-op"] |> join);
};

let initial = .ok({
    aim: 0,
    pos: {x: 0, y: 0},
});
let result = input |> fold(initial, update);
let part_2 = match result {
    .ok({pos: {x, y}}) -> x * y,
    .err(_) -> -1,
};

print part_2;
assert part_2 == 900;
''')),
(SampleName('util/lists.lox'),  SampleContent(r'''let {plus} = import "numeric.lox";

let elements = \list ->
    if list |> List.empty
    then .err(.empty_list)
    else .ok({
            first: list |> List.first,
            rest: list |> List.rest,
          })
;

let fold = \state, fn -> \list {
    let {first, rest} = list |> elements ?? return state;
    let new_state = fn(state, first);
    return rest |> fold(new_state, fn);
};

let try_fold = \initial, fn ->
  fold(
    .ok(initial),
    \state, element -> fn(state!, element),
  );

let map = \fn ->
    fold([], \state, element -> [..state, fn(element)]);

let try_map = \fn ->
  fold(
    .ok([]),
    \state, element -> .ok([
      ..state!,
      fn(element)!,
    ]),
  );

let reduce = \fn -> \list ->
  match list |> elements {
    .err(e) -> .err(e),
    .ok({first, rest}) -> .ok(rest |> fold(first, fn))
  };

let reverse =
    fold([], \state, element -> [element, ..state]);

let where = \fn ->
    fold([], \state, element -> if fn(element) then [..state, element] else state);

let enumerated = \list {
    let result = list |> fold(
        {index: 0, list: []},
        \{index, list}, element -> {
            index: index + 1,
            list: [ ..list, { element, index } ],
        }
    );
    return result.list;
};

let count_where = \predicate ->
    fold(0, \count, element -> if predicate(element) then count + 1 else count);

let sort = \list {
  let {first: x, rest: xs} = list |> elements ?? return [];
  let is_before = \e -> e < x;
  let is_after = \e -> e >= x;
  return [
    ..xs |> where(is_before) |> sort,
    x,
    ..xs |> where(is_after) |> sort
  ];
};

let zip = \list1, list2, fn {
  let l1 = list1 |> elements ?? return [];
  let l2 = list2 |> elements ?? return [];
  return [
      fn(l1.first, l2.first),
      ..zip(l1.rest, l2.rest, fn),
  ];
};

let zip_with_tail = \fn -> \list ->
  match list |> elements {
    .err(_) -> [],
    .ok({rest}) -> zip(list, rest, fn)
  };

let sum = reduce(plus);



let fold_until = \state, fn -> \list {
    let {first, rest} = list |> elements ?? return state;
    let step = fn(state, first);
    return match step {
        .continue(new_state) -> rest |> fold_until(new_state, fn),
        .break(final_state) -> final_state,
    };
};

let any = \predicate ->
    fold_until(
        false,
        \state, element ->
            if predicate(element)
            then .break(true)
            else .continue(state)
    );

let all = \predicate ->
    fold_until(
        true,
        \state, element ->
            if predicate(element)
            then .continue(state)
            else .break(false)
    );

let drop_at = \target_index -> \list ->
    list
        |> enumerated
        |> where(\{index} -> index != target_index)
        |> map(\{element} -> element);

let join = fold("", String.concat);

let element_at = \target_index -> \list ->
    list
        |> enumerated
        |> fold_until(
               .err(.out_of_bounds),
               \state, {index, element} ->
                   if index == target_index
                   then .break(.ok(element))
                   else .continue(state),
           );

let length = fold(0, \count, _ -> count + 1);

let is_empty = \list ->
    match list |> elements {
        .ok(_) -> false,
        .err(_) -> true,
    };
''')),
(SampleName('util/functions.lox'),  SampleContent(r'''let eq = \a -> \b -> a == b;

let try = \f -> \r -> match r {
  .ok(x) -> .ok(f(x)),
  .err(e) -> .err(e),
};
''')),
(SampleName('util/numeric.lox'),  SampleContent(r'''
let abs_diff = \a, b -> if a > b then a - b else b - a;
let abs = \a -> if a >= 0 then a else a * -1;
let plus = \a, b -> a + b;
let minus = \a, b -> a - b;
let sign = \n {
    if n == 0 then return 0;
    if n < 0 then return -1;
    assert n > 0;
    return 1;
};''')),
(SampleName('util/strings.lox'),  SampleContent(r'''let { fold, join, elements, try_map } = import "lists.lox";
let { try } = import "functions.lox";

let split = \{separator} -> \str -> String.split(str, separator);

let split_at = \{separator} -> \str {
    let { first, rest } = str
      |> split({separator})
      |> elements
      ?? return .err(.separator_not_found);
    return .ok({
      before: first,
      after: rest |> join,
    });
};

let as_digit = \str ->
    if str == "0" then .ok(0) else
    if str == "1" then .ok(1) else
    if str == "2" then .ok(2) else
    if str == "3" then .ok(3) else
    if str == "4" then .ok(4) else
    if str == "5" then .ok(5) else
    if str == "6" then .ok(6) else
    if str == "7" then .ok(7) else
    if str == "8" then .ok(8) else
    if str == "9" then .ok(9) else
    .err(.invalid_digit(str));

let parse_int = \str -> str
  |> split({separator: ""})
  |> try_map(as_digit)
  |> try(fold(0, \number, digit -> number * 10 + digit));
'''))
];
