classdef TestRefactor < matlab.unittest.TestCase
    
    properties
        oldpath
        startDir
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            testCase.oldpath = addpath(cd);
            testCase.startDir = cd;
            cd('Example1')
        end
    end
    methods (TestMethodTeardown)
        function tearDown(testCase)
            cd(testCase.startDir)
            path(testCase.oldpath)
        end
    end
    
    methods (Test)
        function testExtractFunction_explicitFunction_noParameters(testCase)
            testFile = 'testFile.m';
            copyfile('printOwing_step1_before.m',testFile);
                        
            Refactor.extractFunction(testFile);
            
            txtExpected = Parser.readFile('printOwing_step1_after.m');            
            txtActual = Parser.readFile(testFile);
            
            testCase.assertEqual(txtActual, txtExpected);
            
            delete(testFile);
        end
        
        function testExtractFunction_toNestedFunction(testCase)
            testFile = 'testFile.m';
            copyfile('printOwing_step2_before.m',testFile);
            
            Refactor.extractFunction(testFile);
            
            txtExpected = Parser.readFile('printOwing_step2_after.m');            
            txtActual = Parser.readFile(testFile);
            
            testCase.assertEqual(txtActual, txtExpected);
            
            delete(testFile);
        end
        
        function testExtractFunction_withReferencedParameters(testCase)
            testFile = 'testFile.m';
            copyfile('printOwing_step3_before.m',testFile);
            
            Refactor.extractFunction(testFile);
            
            txtExpected = Parser.readFile('printOwing_step3_after.m');            
            txtActual = Parser.readFile(testFile);
            
            testCase.assertEqual(txtActual, txtExpected);
            
            delete(testFile);
        end
end
    
end

