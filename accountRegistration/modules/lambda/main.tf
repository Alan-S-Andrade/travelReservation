locals {
  filepath = "${path.module}/../../functions/${var.function_name}/${var.function_name}.zip"
}

data "archive_file" "lambda_archive" {
  type = "zip"
  source_dir  = "${path.module}/../../functions/${var.function_name}/"
  output_path = local.filepath
}

resource "aws_lambda_function" "function" {
  function_name = var.function_name
  runtime       = "python3.8"
  handler       = var.lambda_handler
  filename      = local.filepath
  role          = aws_iam_role.lambda_function_role.arn
  timeout       = 10
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }
}

resource "null_resource" "copy_jsonpickle" {
  provisioner "local-exec" {
    command = "cp -R $(python3 -c 'import jsonpickle; print(jsonpickle.__file__.replace(\"__init__.py\", \"\"))') ${path.module}/../../functions/${var.function_name}/jsonpickle"
  }
  depends_on = [data.archive_file.lambda_archive]
}

resource "aws_cloudwatch_log_group" "aggregator" {
  name = "/aws/lambda/${aws_lambda_function.function.function_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "lambda_function_role" {
  name = "Function_Iam_Role_${var.function_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
