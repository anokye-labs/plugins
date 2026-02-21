@{
    Run = @{
        Path = './tests'
        ExcludePath = './tests/fixtures'
    }
    Output = @{
        Verbosity = 'Detailed'
        CIFormat = 'GitHubActions'
    }
    CodeCoverage = @{
        Enabled = $true
        Path = './scripts'
        OutputFormat = 'JaCoCo'
        OutputPath = './tests/coverage.xml'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './tests/results.xml'
    }
}
