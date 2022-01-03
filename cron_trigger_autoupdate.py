#!/usr/bin/env python
import os
import sys
import logging
from logging import critical, error, info, warning, debug
import subprocess
from psh_logging import outputError


def trigger_autoupdate():
    defaultUpdateBranch = "update"
    defaultProductionBranch = "main"
    defaultSourceOpName = "auto-update"
    defaultUpdateBranchEnvVar = 'PSH_SOP_UPDATE_BRANCH'
    defaultSourceOpNameEnvVar = 'PSH_SOP_NAME'

    def getProductionBranchName():
        """
        Gets the production branch name
        One would think this should be simple, but one would be wrong
        https://platformsh.slack.com/archives/CEDK8KCSC/p1640717471389700
        @todo I dont like mixing return types. Return an empty string if we dont find one and let the calling function
        handle it?
        :return: bool|string: Name of the production branch
        """
        command = "platform environment:list --type production --pipe 2>/dev/null"
        event = "Retrieving production environments"
        prodBranchRun = runCommand(command)
        if not prodBranchRun['result'] or "" == prodBranchRun['message']:
            message = "I was unable to retrieve a list of production type branches for this project. Please create a"
            message += " ticket and ask that it be assigned to the DevRel team.\n\n"
            return outputError(event, message)

        # oh, we're not done yet. It's plausible that in the future, we may have more than one production branch
        # so split the return from the above by line break, and then let's see if we were given exactly one
        prodEnvironments = prodBranchRun['message'].split('\n')
        if 1 != len(prodEnvironments):
            message = "More than one production branch was returned. I was given the following branches:\n{}".format(
                prodBranchRun['message'])
            return outputError(event, message)

        return prodEnvironments[0]

    def syncBranch(updateBranch, productionBranch):
        """
        Syncs the code from production down to our update branch before we run the auto-update source operation
        :param string updateBranch: update branch name
        :param string productionBranch: production branch name
        :return: bool
        """
        logging.info("Syncing branch {} with {}...".format(updateBranch, productionBranch))
        command = "platform sync -e {} --yes --wait code 2>/dev/null".format(updateBranch)
        syncRun = runCommand(command)
        if syncRun['result']:
            logging.info("Syncing complete.")
        else:
            return outputError(command, syncRun['message'])

    def deactivateUpdateBranch(targetEnvironment):
        """
        Sets the environment back to inactive status (ie Deletes the *environment* but not the git branch)
        :param string targetEnvironment: name of branch to deactivate
        :return: bool
        """
        logging.info("Deactivating environment {}".format(targetEnvironment))
        command = "platform e:delete {} --no-delete-branch --no-wait --yes 2>/dev/null"
        deactivateRun = runCommand(command)
        if deactivateRun['result']:
            logging.info("Environment {} deactivated".format(targetEnvironment))
        else:
            return outputError(command, deactivateRun['message'])

    def runSourceOperations(sourceoperation, targetEnvironment):
        """
        Runs the named source operation against a target branch
        :param string sourceoperation: name of the source operation we want to run
        :param string targetEnvironment: name of the branch we want to perform the source operation against
        :return: bool: source operation success
        """
        logging.info(
            "Running source operation '{}' against environment '{}'... ".format(sourceoperation, targetEnvironment))
        command = "platform source-operation:run {} --environment {} --wait 2>/dev/null".format(sourceoperation,
                                                                                                targetEnvironment)
        sourceOpRun = runCommand(command)

        if sourceOpRun['result']:
            logging.info("Source operation completed.")
        else:
            return outputError(command, sourceOpRun['message'])

    def runCommand(command, cwd=None):
        procUpdate = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output, procerror = procUpdate.communicate()

        if 0 == procUpdate.returncode:
            returnStatement = True
            message = output
        else:
            returnStatement = False
            message = procerror

        return {"result": returnStatement, "message": message}

    def getUpdateBranchName():
        """
        Gets the update branch name from the environmental variable PSH_SOP_UPDATE_BRANCH, or defaults to 'update'
        :return: string: targeted update branch name
        """
        return os.getenv(defaultUpdateBranchEnvVar, defaultUpdateBranch)

    def getSourceOpName():
        """
        Gets the source operation name from the environmental variable PSH_SOP_NAME, or defaults to 'auto-update'
        :return: string: source operation name we want to run
        """
        return os.getenv(defaultSourceOpNameEnvVar, defaultSourceOpName)

    def determineBranchAction(updateBranchName):
        """
        We need the update branch, and we need it to be synced with production
        This could mean we need to create the branch, or sync the branch, or do nothing
        :param string updateBranchName: name of branch we will target for updates
        :return: string: action we need to perform on the target branch
        """
        action = 'sync'
        # kill two birds with one stone here: if it doesn't exist, then we'll get an error & know we need to create it.
        # If it exists, then we'll know if we need to sync it
        command = "platform environment:info status -e {} 2>/dev/null".format(updateBranchName)
        branchStatusRun = runCommand(command)

        if 0 != branchStatusRun['result']:
            action = 'create'
        elif 'inactive' == branchStatusRun['message']:
            action = 'activate'

        return action

    def activateBranch(updateBranchName):
        """
        Activate a branch
        :param updateBranchName: name of branch to activate
        :return: bool
        """
        command = "platform environment:activate {} --wait --yes 2>/dev/null".format(updateBranchName)
        logging.info("Activating branch {}...".format(updateBranchName))
        activateBranchRun = runCommand(command)
        if not activateBranchRun['result']:
            event = "Activating branch {}".format(updateBranchName)
            message = "I encountered an error while attempting to activate the branch {}. Please ".format(
                updateBranchName)
            message += "check the activity log to see why activation failed"
            return outputError(event, message)

        logging.info("Environment activated.")
        return True

    def createBranch(updateBranchName, productionBranchName):
        """
        Creates the update branch so we can run source operations against it
        :param string updateBranchName: name of the branch to be created
        :param string productionBranchName: name of the parent branch (production) to create the branch from
        :return: bool
        """
        event = "Creating environment {}".format(updateBranchName)
        logging.info("{}...".format(event))
        command="platform e:branch {} {} --no-clone-parent --force 2>/dev/null".format(updateBranchName, productionBranchName)
        createBranchRun = runCommand(command)
        if not createBranchRun['result']:
            event = "Failure {}".format(event)
            message = "I encountered an error while attempting to create the branch {}.".format(updateBranchName)
            message += " Please check the activity log to see why creation failed"
            outputError(event, message)
        else:
            logging.info("Environment created.")

        return createBranchRun['result']

    def validateUpdateBranchAncestory(updateBranchName, productionBranchName):
        """
        Makes sure the update branch is a direct child of production branch
        :param updateBranchName: Name of the update branch
        :param productionBranchName: Name of the production branch
        :return: bool
        """
        command = "platform environment:info parent -e {} 2>/dev/null".format(updateBranchName)
        branchAncestoryRun = runCommand(command)
        if not branchAncestoryRun['result'] or productionBranchName != branchAncestoryRun['message']:
            event = "Update Branch {} is not a direct descendant of {}".format(updateBranchName, productionBranchName)
            message = "The targeted update branch, {}, is not a direct descendant of the production branch".format(updateBranchName)
            message += " {}. The update branch's parent is {}. ".format(productionBranchName, branchAncestoryRun['message'])
            message += "This automated source operation only supports updating branches that are direct descendants "
            message += "of the production branch"
            return outputError(event, message)

        return True

    def syncBranch(updateBranchName, productionBranchName):
        event = "Sync{} branch {} with {}"
        command = "platform sync -e {} --yes --wait code 2>/dev/null".format(updateBranchName)
        logging.info(event.format('ing',updateBranchName, productionBranchName))
        syncRun = runCommand(command)

        if not syncRun['result']:
            failedEvent="Failed to {}".format(event.format('', updateBranchName, productionBranchName))
            message = "I was unable to sync the environment {} with {}".format(updateBranchName, productionBranchName)
            message += "You will need to examine the logs to find out why"
            outputError(failedEvent, message)
        else:
            logging.info("Syncing complete.")

        return syncRun['result']