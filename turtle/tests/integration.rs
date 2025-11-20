// use std::collections::HashMap;
// use std::sync::{Arc, Mutex};

fn setup_test_config() -> turtle::config::Config {
    let mut config = turtle::config::Config::default();
    config
}

fn setup_test_config_file() -> String {
    let config_content = r#"
        [defaults]
        history_path = "~/.turtle_history_test"
        prompt = "turtle-test> "
    "#;

    let config_path = std::env::temp_dir().join("turtle_test_config.toml");
    std::fs::write(&config_path, config_content).expect("Failed to write test config file");

    config_path.to_string_lossy().to_string()
}

/// Helper to set up a fresh interpreter and context for testing
fn setup_test_env() -> (
    turtle::lang::Interpreter,
    turtle::context::Context,
    std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, turtle::expressions::Expressions>>,
    >,
) {
    let env = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new()));
    let aliases = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new()));
    let vars = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new()));
    let args = std::sync::Arc::new(std::sync::Mutex::new(turtle::config::Arguments {
        // args: vec![],
        version: false,
        debug: false,
        debug_expressions: false,
        debug_tokenization: false,
        debug_context: false,
        available_themes: false,
        command: None,
        format: None,
        config_path: None,
        history_path: None,
        display_defaults: false,
        display_config: false,
        display_env: false,
        display_prompt: false,
        skip_aliases: false,
        skip_history: false,
        watch_config: false,
    }));

    let history = std::sync::Arc::new(std::sync::Mutex::new(turtle::history::History {
        interval: None,
        path: None,
        debug: true,
        events: Some(vec![]),
    }));

    let interpreter = turtle::lang::Interpreter::new(
        Some(args.clone()),
        env.clone(),
        aliases.clone(),
        vars.clone(),
        vec![],
        true,
    );

    let mut context = turtle::context::Context::new(
        None,
        None,
        env,
        aliases.clone(),
        vars.clone(),
        history,
        true,
    );
    context.setup();

    (interpreter, context, vars)
}

/// Helper to assert a numeric result
fn assert_number_result(result: Option<turtle::context::EvalResults>, expected: f64) {
    match result {
        Some(turtle::context::EvalResults::NumberExpressionResult(n)) => {
            assert!(
                (n.value - expected).abs() < 0.0001,
                "Expected {}, got {}",
                expected,
                n.value
            );
        }
        other => panic!(
            "Expected NumberExpressionResult({}), got {:?}",
            expected, other
        ),
    }
}

/// Helper to assert a string result
fn assert_string_result(result: Option<turtle::context::EvalResults>, expected: &str) {
    match result {
        Some(turtle::context::EvalResults::StringExpressionResult(s)) => {
            assert_eq!(s.value, expected);
        }
        other => panic!(
            "Expected StringExpressionResult(\"{}\"), got {:?}",
            expected, other
        ),
    }
}

/// Helper to assert a boolean result
fn assert_boolean_result(result: Option<turtle::context::EvalResults>, expected: bool) {
    match result {
        Some(turtle::context::EvalResults::BooleanExpressionResult(b)) => {
            assert_eq!(b.value, expected);
        }
        other => panic!(
            "Expected BooleanExpressionResult({}), got {:?}",
            expected, other
        ),
    }
}

#[test]
fn test_simple_arithmetic() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("1 + 2");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 3.0);
}

#[test]
fn test_arithmetic_with_spaces() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("10 + 20");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 30.0);
}

#[test]
fn test_arithmetic_without_spaces() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("5+3");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 8.0);
}

#[test]
fn test_subtraction() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("10 - 3");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 7.0);
}

#[test]
fn test_multiplication() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("4 * 5");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 20.0);
}

#[test]
fn test_division() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("15 / 3");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 5.0);
}

#[test]
fn test_mixed_operations() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("2 + 3 * 4 - 5 / 1");
    let expr = interp.interpret();
    let result = ctx.eval(expr);
    // 2 + (3 * 4) - (5 / 1) = 2 + 12 - 5 = 9
    assert_number_result(result, 9.0);
}

#[test]
fn test_variable_assignment() {
    let (mut interp, mut ctx, vars) = setup_test_env();

    interp.tokenize("let a = 42");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::AssignmentExpressionResult(_))
    ));

    // Verify variable was stored
    let stored = vars.lock().unwrap();
    assert!(stored.contains_key("a"));
}

#[test]
fn test_variable_lookup() {
    let (mut interp, mut ctx, _) = setup_test_env();

    // Assign
    interp.tokenize("let a = 42");
    ctx.eval(interp.interpret());

    // Lookup
    interp.tokenize("a");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 42.0);
}

#[test]
fn test_variable_in_expression() {
    let (mut interp, mut ctx, _) = setup_test_env();

    // Set variable
    interp.tokenize("let a = 10");
    ctx.eval(interp.interpret());

    // Use in expression
    interp.tokenize("a + 5");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_number_result(result, 15.0);
}

#[test]
fn test_multiple_variables_in_expression() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("let a = 10");
    ctx.eval(interp.interpret());

    interp.tokenize("let b = 5");
    ctx.eval(interp.interpret());

    interp.tokenize("a + b");
    let result = ctx.eval(interp.interpret());

    assert_number_result(result, 15.0);
}

#[test]
fn test_string_concatenation() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("\"hello\" + \" world\"");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert_string_result(result, "hello world");
}

#[test]
fn test_string_variable() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("let s = \"test\"");
    ctx.eval(interp.interpret());

    interp.tokenize("s");
    let result = ctx.eval(interp.interpret());

    assert_string_result(result, "test");
}

#[test]
fn test_object_with_spaces() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("{foo: 1, bar: 2}");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Object(props)) => {
            assert_eq!(props.len(), 2);
            assert_eq!(props[0].0, "foo");
            assert_eq!(props[1].0, "bar");
        }
        _ => panic!("Expected Object expression"),
    }
}

#[test]
fn test_object_without_spaces() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("{foo:1,bar:2}");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Object(props)) => {
            assert_eq!(props.len(), 2);
            assert_eq!(props[0].0, "foo");
            assert_eq!(props[1].0, "bar");
        }
        _ => panic!("Expected Object expression"),
    }
}

#[test]
fn test_array_with_spaces() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("[1, 2, 3]");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Array(elements)) => {
            assert_eq!(elements.len(), 3);
        }
        _ => panic!("Expected Array expression"),
    }
}

#[test]
fn test_array_without_spaces() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("[1,2,3]");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Array(elements)) => {
            assert_eq!(elements.len(), 3);
        }
        _ => panic!("Expected Array expression"),
    }
}

#[test]
fn test_nested_array() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("[[1, 2], [3, 4]]");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Array(elements)) => {
            assert_eq!(elements.len(), 2);
        }
        _ => panic!("Expected Array expression"),
    }
}

#[test]
fn test_undefined_variable_error() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("undefined_var");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    // Should return error result with message
    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::StringExpressionResult(s))
        if s.value.contains("not defined")
    ));
}

#[test]
fn test_boolean_true() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("True");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::BooleanExpressionResult(b)) if b.value == true
    ));
}

#[test]
fn test_boolean_false() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("False");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::BooleanExpressionResult(b)) if b.value == false
    ));
}

#[test]
fn test_number_literal() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("3.14");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::NumberExpressionResult(n)) if (n.value - 3.14).abs() < 0.001
    ));
}

#[test]
fn test_string_literal() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("\"hello world\"");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::StringExpressionResult(s))
        if s.value == "hello world"
    ));
}

#[test]
fn test_complex_arithmetic() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("2 + 3 * 4");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    // Should respect operator precedence: 2 + (3 * 4) = 14
    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::NumberExpressionResult(n)) if n.value == 14.0
    ));
}

#[test]
fn test_chained_operations() {
    let (mut interp, mut ctx, _) = setup_test_env();

    interp.tokenize("10 - 3 - 2");
    let expr = interp.interpret();
    let result = ctx.eval(expr);

    // Should be left-associative: (10 - 3) - 2 = 5
    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::NumberExpressionResult(n)) if n.value == 5.0
    ));
}

#[test]
fn test_new_array_constructor() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("new Array()");
    let expr = interp.interpret();

    assert!(matches!(
        expr,
        Some(turtle::expressions::Expressions::Array(_))
    ));
}

#[test]
fn test_new_array_with_literal() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("new Array([1, 2, 3])");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Array(elements)) => {
            assert_eq!(elements.len(), 3);
        }
        _ => panic!("Expected Array expression"),
    }
}

#[test]
fn test_new_object_constructor() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("new Object()");
    let expr = interp.interpret();

    assert!(matches!(
        expr,
        Some(turtle::expressions::Expressions::Object(_))
    ));
}

#[test]
fn test_new_object_with_literal() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("new Object({key: \"value\"})");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Object(props)) => {
            assert_eq!(props.len(), 1);
            assert_eq!(props[0].0, "key");
        }
        _ => panic!("Expected Object expression"),
    }
}

#[test]
fn test_assignment_without_let() {
    let (mut interp, mut ctx, vars) = setup_test_env();

    interp.tokenize("y = 100");
    let expr = interp.interpret();
    ctx.eval(expr);

    // Verify variable was stored
    let stored = vars.lock().unwrap();
    assert!(stored.contains_key("y"));
}

#[test]
fn test_reassignment() {
    let (mut interp, mut ctx, _) = setup_test_env();

    // First assignment
    interp.tokenize("let z = 1");
    ctx.eval(interp.interpret());

    // Reassignment
    interp.tokenize("z = 2");
    ctx.eval(interp.interpret());

    // Verify new value
    interp.tokenize("z");
    let result = ctx.eval(interp.interpret());

    assert!(matches!(
        result,
        Some(turtle::context::EvalResults::NumberExpressionResult(n)) if n.value == 2.0
    ));
}

#[test]
fn test_empty_array() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("[]");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Array(elements)) => {
            assert_eq!(elements.len(), 0);
        }
        _ => panic!("Expected Array expression"),
    }
}

#[test]
fn test_empty_object() {
    let (mut interp, _, _) = setup_test_env();

    interp.tokenize("{}");
    let expr = interp.interpret();

    match expr {
        Some(turtle::expressions::Expressions::Object(props)) => {
            assert_eq!(props.len(), 0);
        }
        _ => panic!("Expected Object expression"),
    }
}
